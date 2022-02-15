import json
import client as client
import logger as logger

from base64 import b64decode
from datetime import datetime

SA_ANALYZE_STATEMENTS_URL_PATH = 'AnalyzeStatements'

config = None

def handle_scoring_request(request: dict) -> dict:
    logger.log_received_request('/api/ccr/process')
    logger.log_action("Request", request)
    txn_id = request['txnid']

    # There is only a single payload (FI data) in this sample scenario.
    fi = json.loads(b64decode(str(b64decode(request['payload'][0]['data'][0]['encryptedData']), "utf-8")))
    logger.log_action("Payload", fi)

    # Aggregate the statements using the confidential SA CCR service.
    aggregated_statements = aggregate_statements(txn_id, fi)

    # Compute the score using the aggregated statements.
    score = compute_score(aggregated_statements)
    resp = {
        "ver": "1.0",
        "timestamp": get_current_timestamp(),
        "txnid": txn_id,
        "score": score
    }

    logger.log_action("Response", resp)
    return resp

def aggregate_statements(txn_id: str, fi: dict) -> dict:
    aggregate_statements_req_json = {
        "ver": "1.0",
        "timestamp": get_current_timestamp(),
        "txnid": txn_id,
        "statements": json.dumps(fi)
    }

    # Convert the aggregate statements request body to JSON.
    logger.log_action("Request", aggregate_statements_req_json)
    
    # Send the request to the SA service. The SA service will then aggregate the
    # statements before sending them back to the BRE to compute the score.
    _, analyze_statements_resp_data = client.post_json_request(config.url_sa,
        SA_ANALYZE_STATEMENTS_URL_PATH, aggregate_statements_req_json)

    # Parse the aggregated statements as JSON.
    aggregated_statements = json.loads(analyze_statements_resp_data)
    logger.log_action("Response", aggregated_statements)
    return json.loads(aggregated_statements['response'])

def compute_score(aggregated_statements: dict) -> int:
    current_balance = int(aggregated_statements['Summary']['currentBalance'])
    
    # NOTE: typically, the score computation would use an ML model for inference,
    # but here for simplicity, the sample code just checks the current balance
    # and if it is more than 100K, then approves the loan.
    if current_balance > 100000:
        score = 82
    else:
        score = 41
    logger.log_action("Score", score)
    return score

def get_current_timestamp():
    # Get current datetime in ISO 8601 format.
    return datetime.now().isoformat()
