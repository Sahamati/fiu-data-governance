import json
import uuid

import client as client
import logger as logger

from datetime import datetime

AA_CONSENT_URL_PATH = 'Consent'
AA_CONSENT_HANDLE_URL_PATH = 'Consent/handle'
AA_FI_REQUEST_URL_PATH = 'FI/request'
AA_FI_FETCH_URL_PATH = 'FI/fetch'
BRE_CCR_KEY_URL_PATH = 'api/ccr/key'
BRE_CCR_PROCESS_URL_PATH = 'api/ccr/process'

config = None

# The CCR public key material.
ccr_public_key_material = None

# Map from consent transaction ids to CCR transaction ids.
txn_ids = {}
# Map from consent ids to consent requests.
consent_requests = {}
# Map from consent ids to consent artifacts.
consent_artifacts = {}

def configure_bre_info(request: dict):
    logger.log_debug("Business rule engine URL: " + request['url'])
    config.url_bre = request['url']

async def start_workflow(data_json: dict):
    global ccr_public_key_material
    logger.log_received_request('/FI/request')
    logger.log_debug(data_json)

    # Send the public key request to the confidential BRE service to get a new
    # transaction id generated by the CCR and the CCR public key material.
    ccr_key_resp = get_ccr_public_key()
    logger.log_action("Response", ccr_key_resp)
    ccr_txn_id = ccr_key_resp['txnid']
    ccr_public_key_material = ccr_key_resp['KeyMaterial']

    # Create a new transaction id for the consent request.
    txn_id = str(uuid.uuid4())
    txn_ids.update({txn_id : ccr_txn_id})

    # Create the consent request body.
    consent_req_json = {
        "ver": "1.0",
        "timestamp": get_current_timestamp(),
        "txnid": txn_id,
        "ConsentDetail": {
            "confidentialMode": data_json['confidentialMode'],
            "consentStart": data_json['consentStart'],
            "consentExpiry": data_json['consentExpiry'],
            "consentMode": data_json['consentMode'],
            "fetchType": data_json['fetchType'],
            "consentTypes": data_json['consentTypes'],
            "fiTypes": data_json['fiTypes'],
            "DataConsumer": {
                "id": data_json['DataConsumer']['id']
            },
            "DataProvider": {
                "id": data_json['DataProvider']['id']
            },
            "Customer": {
                "id": data_json['Customer']['id']
            },
            "Accounts": [],
            "Purpose": {
                "code": data_json['Purpose']['code'],
                "refUri": data_json['Purpose']['refUri'],
                "text": data_json['Purpose']['text']
            },
            "FIDataRange": {
                "from": data_json['FIDataRange']['from'],
                "to": data_json['FIDataRange']['to']
            },
            "DataLife": {
                "unit": data_json['DataLife']['unit'],
                "value": data_json['DataLife']['value']
            },
            "Frequency": {
                "unit": data_json['Frequency']['unit'],
                "value": data_json['Frequency']['value']
            },
            "DataFilter": data_json['DataFilter']
        }
    }
    
    # Send the consent request to the AA service.
    logger.log_action("Request", consent_req_json)
    _, consent_resp_data = client.post_json_request(config.url_aa, AA_CONSENT_URL_PATH, consent_req_json)

    # Parse the consent response as JSON.
    consent_resp = json.loads(consent_resp_data)
    logger.log_action("Response", consent_resp)

    # Add the consent handle to the request URL path.
    url_path = AA_CONSENT_HANDLE_URL_PATH + "/" + consent_resp['ConsentHandle']
    _, consent_handle_resp_data = client.get_json_request(config.url_aa, url_path, None)

    # Parse the consent handle response as JSON.
    consent_handle_resp = json.loads(consent_handle_resp_data)
    logger.log_action("Response", consent_handle_resp)

    # Store the consent request using the transaction id as key.
    # NOTE: for now this is simply in-memory.
    consent_requests.update({txn_id : consent_req_json})

async def handle_consent_notification(request: dict):
    logger.log_received_request('/Consent/Notification')
    logger.log_debug(request)

    # TODO: fail gracefully if consent is not granted.

    # Add the consent id to the request URL path.
    consent_id = request["ConsentStatusNotification"]["consentId"]
    url_path = AA_CONSENT_URL_PATH + "/" + consent_id

    # Send the consent request to the AA service.
    _, consent_artifact_data = client.get_json_request(config.url_aa, url_path, None)

    # Parse the consent artifact as JSON.
    consent_artifact = json.loads(consent_artifact_data)
    logger.log_action("Consent Artifact", consent_artifact)

    txn_id = consent_artifact["txnid"]
    consent_artifacts.update({txn_id : consent_artifact})
    assert(txn_id in consent_requests)
    consent_req = consent_requests[txn_id]

    # Create the FI request body.
    fi_req_json = {
        "ver": "1.0",
        "timestamp": get_current_timestamp(),
        "txnid": consent_artifact['txnid'],
        "FIDataRange": {
            "from": consent_req["ConsentDetail"]["FIDataRange"]["from"],
            "to": consent_req["ConsentDetail"]["FIDataRange"]["to"]
        },
        "Consent": {
            "id": consent_artifact["consentId"],
            "digitalSignature": consent_artifact["signedConsent"]
        },
        "KeyMaterial": {
            "cryptoAlg": ccr_public_key_material['cryptoAlg'],
            "curve": ccr_public_key_material['curve'],
            "params": ccr_public_key_material['params'],
            "DHPublicKey": {
                "expiry": ccr_public_key_material['DHPublicKey']['expiry'],
                "Parameters": ccr_public_key_material['DHPublicKey']['Parameters'],
                "KeyValue": ccr_public_key_material['DHPublicKey']['KeyValue']
            },
            "Nonce": ccr_public_key_material['Nonce']
        }
    }

    # Send the FI request to the AA service.
    logger.log_action("Request", fi_req_json)
    _, fi_resp = client.post_json_request(config.url_aa, AA_FI_REQUEST_URL_PATH, fi_req_json)
    logger.log_action("Response", fi_resp)

async def handle_fi_notification(request: dict):
    logger.log_received_request('/FI/Notification')
    logger.log_debug(request)

    # Add the session id to the request URL path.
    url_path = AA_FI_FETCH_URL_PATH + "/" + request["FIStatusNotification"]["sessionId"]
    
    # Send the FI fetch request to the AA service.
    _, fi_fetch_resp_data = client.get_json_request(config.url_aa, url_path, None)

    # Parse the FI fetch response as JSON.
    fi_fetch_resp = json.loads(fi_fetch_resp_data)
    logger.log_action("Response", fi_fetch_resp)

    txn_id = fi_fetch_resp['txnid']
    assert(txn_id in txn_ids)
    ccr_txn_id = txn_ids[txn_id]

    # Get the consent artefact.
    assert(txn_id in consent_artifacts)
    consent_artifact = consent_artifacts[txn_id]

    # Create the CCR process request payload containing the encrypted FI and FIP key material.
    process_req_json = {
        "ver": "1.0",
        "timestamp": get_current_timestamp(),
        "txnid": ccr_txn_id,
        "payload": convert_fi_data_to_ccr_json(fi_fetch_resp['FI']),
        "Consent": {
            "signature": "...",
            "consentArtefact": consent_artifact
        }
    }

    # Send the request to the confidential BRE CCR service.
    logger.log_action("Application request", process_req_json)
    status, process_resp_data = client.post_json_request(config.url_bre, BRE_CCR_PROCESS_URL_PATH, process_req_json)

    # Parse the response as JSON.
    process_resp = json.loads(process_resp_data)
    if status == 200:
        logger.log_action("Response", process_resp)
        resp = process_resp['score']
        logger.log_action("Score", resp)
    else:
        raise Exception(f"Request failed.")

def convert_fi_data_to_ccr_json(fi_json: dict):
    payload = []
    for item in fi_json:
        payload_json = {
            "id": item["fipID"],
            "data": [],
            "KeyMaterial": item["KeyMaterial"]
        }
        for data_item in item["data"]:
            payload_json["data"].append({
                "encryptedData": data_item["encryptedFI"],
                "metadata": "..."
            })
        payload.append(payload_json)
    return payload

def get_ccr_public_key() -> dict:
    # Send the key request to the BRE CCR service. The response will contain
    # the transaction id and the confidential clean room (CCR) key material.
    _, resp_data = client.get_json_request(config.url_bre, BRE_CCR_KEY_URL_PATH, None)
    return json.loads(resp_data)

def verify_txn_id(txn_id: str, txn_id_expected: str):
    if not txn_id == txn_id_expected:
        raise Exception(f"The received txn id '{txn_id}' does not match '{txn_id_expected}'.")

def verify_nonce(nonce: str, nonce_expected: str):
    if not nonce == nonce_expected:
        raise Exception(f"The received nonce '{nonce}' does not match '{nonce_expected}'.")

def get_current_timestamp():
    # Get current datetime in ISO 8601 format.
    return datetime.now().isoformat()
