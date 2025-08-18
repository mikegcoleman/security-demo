# Binary Authorization Policy
resource "google_binary_authorization_policy" "policy" {
  project = var.project_id

  # Admission whitelist patterns
  admission_whitelist_patterns {
    name_pattern = "reg.kyverno.io/**"
  }
  
  admission_whitelist_patterns {
    name_pattern = "ghcr.io/kyverno/**"
  }

  # Default admission rule - REQUIRE_ATTESTATION for production
  default_admission_rule {
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    
    require_attestations_by = [
      google_binary_authorization_attestor.attestor.name
    ]
  }

  global_policy_evaluation_mode = "ENABLE"

  depends_on = [google_project_service.apis]
}

# Binary Authorization Attestor using KMS key
resource "google_binary_authorization_attestor" "attestor" {
  project = var.project_id
  name    = "signed-images-attestor"

  attestation_authority_note {
    note_reference = google_container_analysis_note.note.name
    
    public_keys {
      id = "//cloudkms.googleapis.com/v1/projects/${var.project_id}/locations/us-west1/keyRings/binauthz-keyring/cryptoKeys/binauthz-kms-key-name/cryptoKeyVersions/1"
      
      pkix_public_key {
        public_key_pem      = <<-EOT
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEaBJfUfQv1xiObLLnoHObGhrErTSF
YJyWY/CtHTVxO6/2gC6iBbOQnek+hFBgxSMaRcwDKw1LUnRk8/Wl9B6r1w==
-----END PUBLIC KEY-----
EOT
        signature_algorithm = "ECDSA_P256_SHA256"
      }
    }
  }

  depends_on = [google_project_service.apis]
}

# Container Analysis Note for attestor
resource "google_container_analysis_note" "note" {
  project = var.project_id
  name    = "signed-images-note"

  attestation_authority {
    hint {
      human_readable_name = "Signed Images Attestor"
    }
  }

  depends_on = [google_project_service.apis]
}