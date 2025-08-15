#!/usr/bin/env python3

import os
import time
from flask import Flask, jsonify
from pymongo import MongoClient
from pymongo.errors import ConnectionFailure, ServerSelectionTimeoutError

app = Flask(__name__)

# db connection details
MONGO_HOST = "10.0.2.7"
MONGO_PORT = 27017
MONGO_USER = "appuser"
MONGO_PASS = "apppass123"
MONGO_DB = "appdb"
MONGO_URI = f"mongodb://{MONGO_USER}:{MONGO_PASS}@{MONGO_HOST}:{MONGO_PORT}/{MONGO_DB}"

def test_mongo_connection():
    """Test MongoDB connection and return status"""
    try:
        client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
        # test connection
        client.admin.command('ismaster')
        
        # insert test doc
        db = client[MONGO_DB]
        collection = db.test_collection
        test_doc = {
            "message": "hello from k8s app",
            "timestamp": time.time(),
            "source": "security-demo-app"
        }
        result = collection.insert_one(test_doc)
        
        # count docs
        doc_count = collection.count_documents({})
        
        client.close()
        
        return {
            "status": "connected",
            "host": MONGO_HOST,
            "port": MONGO_PORT,
            "inserted_id": str(result.inserted_id),
            "total_docs": doc_count,
            "error": None
        }
        
    except (ConnectionFailure, ServerSelectionTimeoutError) as e:
        return {
            "status": "failed",
            "host": MONGO_HOST,
            "port": MONGO_PORT,
            "inserted_id": None,
            "total_docs": None,
            "error": str(e)
        }
    except Exception as e:
        return {
            "status": "error",
            "host": MONGO_HOST,
            "port": MONGO_PORT,
            "inserted_id": None,
            "total_docs": None,
            "error": str(e)
        }

@app.route('/')
def home():
    return jsonify({
        "app": "security-demo-mongodb-test",
        "status": "running",
        "endpoints": ["/", "/test-db", "/health"]
    })

@app.route('/test-db')
def test_db():
    """test db connection"""
    result = test_mongo_connection()
    status_code = 200 if result["status"] == "connected" else 500
    return jsonify(result), status_code

@app.route('/health')
def health():
    return jsonify({"status": "healthy"}), 200

if __name__ == '__main__':
    print(f"Starting app - will try to connect to MongoDB at {MONGO_URI}")

    app.run(host='0.0.0.0', port=8080, debug=True)