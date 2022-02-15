import uuid
import logger as logger

from datetime import datetime

# The AA certificate (currently we naively store in memory).
certificate = None

# Simple handler that returns the AA entity information.
def handle_aa_entity_info_request():
    logger.log_received_request('/entityInfo/AA')
    # Creates the AA entity info response and attaches the certificate.
    # NOTE: In this sample, there is only one AA entity.
    response = [{
        "ver": "1.0",
        "timestamp": get_current_timestamp(),
        "txnid": str(uuid.uuid4()),
        "requester": {
            "name": "...",
            "id": "..."
        },
        "entityinfo": {
            "name": "...",
            "id": "fip123456789id",
            "code": "...",
            "entityhandle": "...",
            "Identifiers": [{
                "category": "...",
                "type": "..."
            }],
            "baseurl": "...",
            "webviewurl": "...",
            "fitypes": ["..."],
            "certificate": certificate,
            "tokeninfo": {
                "url": "null",
                "desc": "string"
            },
            "signature": {
                "signValue": "..."
            },
            "inboundports": ["..."],
            "outboundports": [],
            "ips": ["..."]
        }
    }]

    logger.log_debug(response)
    return response

def get_current_timestamp():
    # Get current datetime in ISO 8601 format.
    return datetime.now().isoformat()
