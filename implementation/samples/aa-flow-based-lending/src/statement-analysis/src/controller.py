import json
import logger as logger

from datetime import datetime

# Simple handler that aggregates statements that were sent for analysis.
def handle_analyze_statements(request: dict):
    logger.log_received_request('/AnalyzeStatements')
    logger.log_debug(request)

    processed_request = ""
    statements = json.loads(request["statements"])
    logger.log_action("Statements", statements)
    
    cash_flow_txns = []
    current_date = statements["Transactions"]["Transaction"][0]["valueDate"]
    total_credit = 0
    total_debit = 0
    closing_balance = 0

    # Iterate and aggregate statements per day.
    for transaction in statements["Transactions"]["Transaction"]:
        if current_date != transaction["valueDate"]:
            cash_flow_txns.append({
                        "txnDate": current_date,
                        "totalCredit": total_credit,
                        "totalDebit": total_debit,
                        "closingBalance": closing_balance
                    })
            current_date = transaction["valueDate"]
            total_credit = 0
            total_debit = 0
        if transaction["type"] == "CREDIT":
            total_credit += transaction["amount"]
            closing_balance = transaction["currentBalance"]
        else:
            total_debit += transaction["amount"]
            closing_balance = transaction["currentBalance"]
    cash_flow_txns.append({
            "txnDate": current_date,
            "totalCredit": total_credit,
            "totalDebit": total_debit,
            "closingBalance": closing_balance
        })

    statements["Transactions"]["Transaction"] = cash_flow_txns

    logger.log_action("Aggregated statements", statements)
    processed_request = json.dumps(statements)

    response = {
        "ver": "1.0",
        "timestamp": get_current_timestamp(),
        "txnid": request["txnid"],
        "response": processed_request
    }
    logger.log_debug(response)
    return response

def get_current_timestamp():
    # Get current datetime in ISO 8601 format.
    return datetime.now().isoformat()
