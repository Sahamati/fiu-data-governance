import asyncio
import json
import uuid

import client as client
import logger as logger

from base64 import b64encode
from datetime import datetime

from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from jose import jwk, constants, jws

CR_CERTIFICATE_URL_PATH = 'certificate/AA'
FIU_CONSENT_NOTIFICATION_URL_PATH = 'Consent/Notification'
FIU_FI_NOTIFICATION_URL_PATH = 'FI/Notification'
CRYPTO_KEYGEN_PATH = '/ecc/v1/generateKey'
CRYPTO_ENCRYPT_PATH = '/ecc/v1/encrypt'
CRYPTO_DECRYPT_PATH = '/ecc/v1/decrypt'

config = None

# Crypto keys (stored in memory for the purposes of this sample).
crypto_keys = None

# FI data in JSON (stored in memory for the purposes of this sample).
fi_data_json = None

# Maps from consent handles to ids and claims.
consent_handles = {}
consent_claims = {}

# Map from ids to artifacts.
consent_artifacts = {}

# Map from session ids to responses.
sessions = {}

# Create RSA key-pair for consent signing and verification.
consent_key = rsa.generate_private_key(
    public_exponent=65537,
    key_size=2048,
    backend=default_backend()
)

async def setup_certificate(request: dict):
    logger.log_debug("Certificate registry URL: " + request['url'])
    config.url_cr = request['url']
    # Extract public key in jwk format.
    public_key = consent_key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
    )
    public_jwk = json.dumps(jwk.RSAKey(algorithm=constants.Algorithms.RS256, key=public_key.decode('utf-8')).to_dict())
    # Store the public key with the CR service.
    cr_req_json = json.loads(public_jwk)
    logger.log_action("Request", cr_req_json)
    status, cr_resp_data = client.post_json_request(config.url_cr, CR_CERTIFICATE_URL_PATH, cr_req_json)
    if status != 200:
        raise Exception(f"Store certificate request to the CR service failed with status {status}")
    logger.log_action("Response", cr_resp_data)

async def handle_consent(consent_handle: str, request: dict) -> dict:
    logger.log_received_request('/Consent')
    txn_id = request["txnid"]

    # Store the consent id and claims using the consent handler as key.
    # NOTE: for now this is simply in-memory.
    consent_handles.update({consent_handle : (txn_id, str(uuid.uuid4()))})
    consent_claims.update({consent_handle : request["ConsentDetail"]})

    # Create the result of the request.
    return {
        "ver": "1.0",
        "timestamp": get_current_timestamp(),
        "txnid": txn_id,
        "Customer": {
            "id": request["ConsentDetail"]["Customer"]["id"]
        },
        "ConsentHandle": consent_handle
    }

async def handle_consent_handle(consent_handle: str) -> dict:
    logger.log_received_request(f'/Consent/handle/{consent_handle}')
    assert(consent_handle in consent_handles)
    txn_id, consent_id = consent_handles[consent_handle]
    if (consent_id in consent_artifacts):
        consent_status = "READY"
    else:
        consent_status = "PENDING"

    # Create the result of the request.
    return {
        "ver": "1.0",
        "timestamp": get_current_timestamp(),
        "txnid": txn_id,
        "ConsentHandle": consent_handle,
        "ConsentStatus": {
            "id": consent_id,
            "status": consent_status
        }
    }

async def create_consent_artifact(consent_handle: str, request: dict):
    # TODO: fix race condition with this happening before the FIU sends the Consent/handle/{} request,
    # causing the two services to hang. For now we have an artificial delay.
    await asyncio.sleep(3)
    
    assert(consent_handle in consent_handles)
    txn_id, consent_id = consent_handles[consent_handle]
    # Create the consent artefact.
    artefact = {
        "ver": "1.0",
        "txnid": txn_id,
        "consentId": consent_id,
        "status": "ACTIVE",
        "createTimestamp": get_current_timestamp(),
        "signedConsent": get_consent_signature(consent_handle),
        "ConsentUse": {
            "logUri": "",
            "count": 1,
            "lastUseDateTime": get_current_timestamp()
        }
    }

    # Store the consent artefact using the consent id as key.
    # NOTE: this is just in-memory for the purposes of this sample.
    consent_artifacts.update({consent_id : artefact})
    logger.log_action("Consent Artifact", "created")

    # Create the notification request body.
    fi_req_json = {
        "ver": "1.0",
        "timestamp": get_current_timestamp(),
        "txnid": txn_id,
        "Notifier": {
            "type": "AA",
            "id": config.id
        },
        "ConsentStatusNotification": {
            "consentId": consent_id,
            "consentHandle": consent_handle,
            "consentStatus": "ACTIVE"
        }
    }
    
    # Send the notification request to the FIU service.
    logger.log_action("Request", fi_req_json)
    _, fi_notification_resp = client.post_json_request(config.url_fiu, FIU_CONSENT_NOTIFICATION_URL_PATH, fi_req_json)
    logger.log_action("Response", fi_notification_resp)

async def get_consent_artifact(consent_id: str) -> dict:
    logger.log_received_request(f'/Consent/{consent_id}')
    assert(consent_id in consent_artifacts)
    # Get the stored response.
    # NOTE: this is just in-memory for the purposes of this sample.
    resp = consent_artifacts[consent_id]
    logger.log_action("Response", resp)
    return resp

async def handle_fi_request(session_id: str, request: dict):
    global crypto_keys
    logger.log_received_request('/FI/request')
    logger.log_debug(request)

    if fi_data_json is None:
        raise Exception("Missing FI data.")
    
    if crypto_keys is None:
        # There are no crypto keys yet, ask the crypto sidecar to create them.
        _, keygen_resp = client.get_json_request(config.url_crypto, CRYPTO_KEYGEN_PATH, None)
        logger.log_action("Response", keygen_resp)
        crypto_keys = json.loads(keygen_resp)

    # NOTE: we just assign a dummy nonce for the purposes of this sample.
    nonce = "KC7Cbk0BvEttWWOgUmT619TfNhzxKtUr1OhO4FKLlxI="

    # Encrypt the FI data with the public key material given by the FIU using the crypto client.
    encoded_fi_data = str(b64encode(json.dumps(fi_data_json).encode("utf-8")), "utf-8")
    crypto_req = {
        "base64Data": encoded_fi_data,
        "base64RemoteNonce": request["KeyMaterial"]['Nonce'],
        "base64YourNonce": nonce,
        "ourPrivateKey": crypto_keys['privateKey'],
        "remoteKeyMaterial": {
            "DHPublicKey": {
                "KeyValue": request["KeyMaterial"]['DHPublicKey']['KeyValue'],
                "Parameters": request["KeyMaterial"]['DHPublicKey']['Parameters'],
                "expiry": request["KeyMaterial"]['DHPublicKey']['expiry']
            },
            "cryptoAlg": request["KeyMaterial"]['cryptoAlg'],
            "curve": request["KeyMaterial"]['curve'],
            "params": request["KeyMaterial"]['params']
        }
    }

    logger.log_action("Request", crypto_req)
    _, encryption_resp = client.post_json_request(config.url_crypto, CRYPTO_ENCRYPT_PATH, crypto_req)
    logger.log_action("Response", encryption_resp)
    encryption_resp_json = json.loads(encryption_resp)
    
    # Create the result of the request.
    result = {
        "ver": "1.0",
        "timestamp": get_current_timestamp(),
        "txnid": request["txnid"],
        "FI": [
            {
                "fipID": "FIP-1",
                "data": [
                    {
                        "linkRefNumber": "XXXX-XXXX-XXXX",
                        "maskedAccNumber": "XXXXXXXX4020",
                        "encryptedFI": encryption_resp_json['base64Data']
                    }
                ],
                "KeyMaterial": {
                    "cryptoAlg": crypto_keys['KeyMaterials']['cryptoAlg'],
                    "curve": crypto_keys['KeyMaterials']['curve'],
                    "params": crypto_keys['KeyMaterials']['params'],
                    "DHPublicKey": {
                        "expiry": crypto_keys['KeyMaterials']['DHPublicKey']['expiry'],
                        "Parameters": crypto_keys['KeyMaterials']['DHPublicKey']['Parameter'],
                        "KeyValue": crypto_keys['KeyMaterials']['DHPublicKey']['KeyValue']
                    },
                    "Nonce": nonce
                }
            }
        ]
    }
    
    # Store the result using the session id as key.
    # NOTE: this is just in-memory for the purposes of this sample.
    sessions.update({session_id : result})

    # Create the notification request body.
    fi_req_json = {
        "ver": "1.0",
        "timestamp": get_current_timestamp(),
        "txnid": request["txnid"],
        "Notifier": {
            "type": "AA",
            "id": config.id
        },
        "FIStatusNotification": {
            "sessionId": session_id,
            "sessionStatus": "COMPLETED",
            "FIStatusResponse": []
        }
    }

    # Send the notification request to the FIU service.
    logger.log_action("Request", fi_req_json)
    _, fi_notification_resp = client.post_json_request(config.url_fiu, FIU_FI_NOTIFICATION_URL_PATH, fi_req_json)
    logger.log_action("Response", fi_notification_resp)

async def handle_fi_fetch(session_id: str, fip_id: str, link_ref_number: str) -> dict:
    logger.log_received_request(f'/FI/fetch/{session_id}')
    assert(session_id in sessions)
    # Get the stored response.
    # NOTE: this is just in-memory for the purposes of this sample.
    resp = sessions[session_id]
    logger.log_action("Response", resp)
    return resp

def get_current_timestamp():
    # Get current datetime in ISO 8601 format.
    return datetime.now().isoformat()

def get_consent_signature(consent_handle: str) -> str:
    # Get the stored consent.
    # NOTE: this is just in-memory for the purposes of this sample.
    claims = consent_claims[consent_handle]
    # Sign the consent with the private key.
    private_key = consent_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.TraditionalOpenSSL,
        encryption_algorithm=serialization.NoEncryption()
    )
    signed_token = jws.sign(claims, private_key, algorithm='RS256')
    logger.log_action("Consent Signature", signed_token)
    return signed_token
