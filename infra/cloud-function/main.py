import base64
import json
import logging
import os
from datetime import datetime
from typing import Dict, Any

from google.cloud import securitycenter
from google.cloud import pubsub_v1
import functions_framework

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Security Center client
scc_client = securitycenter.SecurityCenterClient()

def process_falco_alert(cloud_event):
    """
    Cloud Function triggered by Pub/Sub messages from Google Cloud Monitoring alerts.
    Transforms Falco alerts into Security Command Center findings.
    
    Args:
        cloud_event: CloudEvent containing the Pub/Sub message
    """
    try:
        # Decode the Pub/Sub message
        pubsub_message = base64.b64decode(cloud_event.data["message"]["data"]).decode()
        alert_data = json.loads(pubsub_message)
        
        logger.info(f"Processing alert: {alert_data.get('incident', {}).get('policy_name', 'Unknown')}")
        
        # Extract relevant information from the alert
        incident = alert_data.get('incident', {})
        policy_name = incident.get('policy_name', 'Unknown Policy')
        condition = incident.get('condition_name', 'Unknown Condition')
        summary = incident.get('summary', 'Falco security alert triggered')
        state = incident.get('state', 'OPEN')
        
        # Extract resource information
        resource_info = extract_resource_info(alert_data)
        
        # Create SCC finding
        finding = create_scc_finding(
            policy_name=policy_name,
            condition=condition,
            summary=summary,
            state=state,
            resource_info=resource_info,
            alert_data=alert_data
        )
        
        # Submit to Security Command Center
        project_id = os.environ.get('PROJECT_ID')
        source_name = f"projects/{project_id}/sources/{get_or_create_source()}"
        
        request = securitycenter.CreateFindingRequest(
            parent=source_name,
            finding_id=generate_finding_id(alert_data),
            finding=finding
        )
        
        response = scc_client.create_finding(request=request)
        logger.info(f"Successfully created SCC finding: {response.name}")
        
        return {"status": "success", "finding_name": response.name}
        
    except Exception as e:
        logger.error(f"Error processing alert: {str(e)}")
        raise

def extract_resource_info(alert_data: Dict[str, Any]) -> Dict[str, Any]:
    """Extract resource information from the alert data."""
    incident = alert_data.get('incident', {})
    
    # Try to extract Kubernetes resource info from logs
    resource_labels = {}
    
    # Look for resource information in the incident
    if 'resource' in incident:
        resource = incident['resource']
        resource_labels = {
            'cluster_name': resource.get('labels', {}).get('cluster_name', 'unknown'),
            'namespace': resource.get('labels', {}).get('namespace_name', 'unknown'),
            'pod_name': resource.get('labels', {}).get('pod_name', 'unknown'),
            'project_id': resource.get('labels', {}).get('project_id', os.environ.get('PROJECT_ID'))
        }
    
    return resource_labels

def create_scc_finding(policy_name: str, condition: str, summary: str, 
                      state: str, resource_info: Dict[str, Any], 
                      alert_data: Dict[str, Any]) -> securitycenter.Finding:
    """Create a Security Command Center finding from alert data."""
    
    # Map alert state to SCC state
    scc_state = securitycenter.Finding.State.ACTIVE
    if state == 'CLOSED':
        scc_state = securitycenter.Finding.State.INACTIVE
    
    # Determine severity based on policy name and content
    severity = determine_severity(policy_name, summary, alert_data)
    
    # Create the finding
    finding = securitycenter.Finding(
        name="",  # Will be set by SCC
        state=scc_state,
        resource_name=f"//container.googleapis.com/projects/{resource_info.get('project_id')}/locations/{resource_info.get('cluster_location', 'unknown')}/clusters/{resource_info.get('cluster_name')}",
        category="FALCO_RUNTIME_SECURITY",
        external_uri="",
        source_properties={
            "policy_name": policy_name,
            "condition": condition,
            "falco_rule": extract_falco_rule_name(summary),
            "cluster_name": resource_info.get('cluster_name', 'unknown'),
            "namespace": resource_info.get('namespace', 'unknown'),
            "pod_name": resource_info.get('pod_name', 'unknown'),
            "alert_timestamp": datetime.utcnow().isoformat(),
            "original_alert": json.dumps(alert_data)
        },
        severity=severity,
        create_time=datetime.utcnow(),
        event_time=datetime.utcnow()
    )
    
    # Add description based on Falco rule type
    finding.description = generate_finding_description(policy_name, summary, resource_info)
    
    return finding

def determine_severity(policy_name: str, summary: str, alert_data: Dict[str, Any]) -> securitycenter.Finding.Severity:
    """Determine finding severity based on alert content."""
    summary_lower = summary.lower()
    policy_lower = policy_name.lower()
    
    # High severity indicators
    high_severity_keywords = [
        'shell', 'exec', 'privilege', 'root', 'sudo', 'sensitive', 
        'password', 'secret', 'token', 'crypto', 'mining'
    ]
    
    # Medium severity indicators  
    medium_severity_keywords = [
        'network', 'file', 'process', 'syscall', 'mount', 'capability'
    ]
    
    if any(keyword in summary_lower or keyword in policy_lower for keyword in high_severity_keywords):
        return securitycenter.Finding.Severity.HIGH
    elif any(keyword in summary_lower or keyword in policy_lower for keyword in medium_severity_keywords):
        return securitycenter.Finding.Severity.MEDIUM
    else:
        return securitycenter.Finding.Severity.LOW

def extract_falco_rule_name(summary: str) -> str:
    """Extract Falco rule name from alert summary."""
    # Try to extract rule name from summary (Falco typically includes rule name)
    if "rule=" in summary:
        try:
            rule_part = summary.split("rule=")[1].split()[0]
            return rule_part.strip('"')
        except:
            pass
    
    # Fallback to looking for common Falco rule patterns
    falco_rules = [
        "Terminal shell in container", "Write below binary dir", "Read sensitive file untrusted",
        "Drop and execute new binary in container", "Change thread namespace", 
        "Modify binary dirs", "Mount launched in privileged container"
    ]
    
    for rule in falco_rules:
        if rule.lower() in summary.lower():
            return rule
    
    return "Unknown Falco Rule"

def generate_finding_description(policy_name: str, summary: str, resource_info: Dict[str, Any]) -> str:
    """Generate a human-readable description for the finding."""
    description = f"Falco runtime security alert triggered: {policy_name}\n\n"
    description += f"Summary: {summary}\n\n"
    description += f"Resource Details:\n"
    description += f"- Cluster: {resource_info.get('cluster_name', 'unknown')}\n"
    description += f"- Namespace: {resource_info.get('namespace', 'unknown')}\n"
    description += f"- Pod: {resource_info.get('pod_name', 'unknown')}\n\n"
    description += "This finding was automatically generated from a Falco runtime security alert."
    
    return description

def generate_finding_id(alert_data: Dict[str, Any]) -> str:
    """Generate a unique finding ID based on alert data."""
    incident = alert_data.get('incident', {})
    policy_name = incident.get('policy_name', 'unknown')
    timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
    
    # Create a simple but unique ID
    finding_id = f"falco_{policy_name.lower().replace(' ', '_')}_{timestamp}"
    return finding_id

def get_or_create_source() -> str:
    """Get or create a Security Command Center source for Falco findings."""
    project_id = os.environ.get('PROJECT_ID')
    org_name = f"projects/{project_id}"
    
    # For project-level findings, we use a static source ID
    # In a real org-level deployment, you'd create/manage sources differently
    source_id = "falco-runtime-security"
    
    try:
        # Try to get existing source first
        source_name = f"{org_name}/sources/{source_id}"
        source = scc_client.get_source(name=source_name)
        logger.info(f"Using existing source: {source.name}")
        return source_id
    except:
        # Source doesn't exist, but for project-level we can't create sources
        # This will need org-level permissions to create sources
        logger.warning("Source doesn't exist - using default source pattern")
        return source_id