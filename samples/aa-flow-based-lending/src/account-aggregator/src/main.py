import argparse
import asyncio
import sys
import uuid
import uvicorn

import controller as controller
import logger as logger

from fastapi import FastAPI, Request, Header, Query
from fastapi.responses import JSONResponse
from typing import List, Optional

app = FastAPI()

# Sets the certificate registry URL for the workflow of this sample.
@app.post("/setup/cr-info")
async def setup_cr_url(request: Request):
    request = await request.json()
    await controller.setup_certificate(request)

# Sets the AA state for the workflow of this sample.
@app.post("/setup/statements")
async def setup_statements(request: Request):
    statements = await request.json()
    controller.fi_data_json = statements

@app.post("/Consent")
async def process_consent(request: Request, x_jws_signature: str = Header(None)):
    consent_handle = str(uuid.uuid4())
    request = await request.json()
    resp = await controller.handle_consent(consent_handle, request)
    # Create async task to create the consent artifact.
    asyncio.ensure_future(controller.create_consent_artifact(consent_handle, request))
    return JSONResponse(content=resp)

@app.get("/Consent/handle/{consentHandle}")
async def get_consent_handle(consentHandle: str, x_jws_signature: str = Header(None)):
    resp = await controller.handle_consent_handle(consentHandle)
    return JSONResponse(content=resp)

@app.get("/Consent/{id}")
async def get_consent(id: str, x_jws_signature: str = Header(None)):
    resp = await controller.get_consent_artifact(id)
    return JSONResponse(content=resp)

@app.post("/FI/request")
async def process_fi_request(request: Request, x_jws_signature: str = Header(None)):
    sessionId = str(uuid.uuid4())
    request = await request.json()

    # Create async task to handle the request.
    asyncio.ensure_future(controller.handle_fi_request(sessionId, request))
    
    # Return the response including a sessionId the client can use
    # to asynchronously query the result.
    return JSONResponse(content={
        "ver": "1.0",
        "timestamp": controller.get_current_timestamp(),
        "txnid": request["txnid"],
        "consentId": request["Consent"]["id"],
        "sessionId": sessionId
    })

@app.get("/FI/fetch/{sessionId}")
async def get_fi_response(
    sessionId: str,
    x_jws_signature: str = Header(None),
    fipId: Optional[str] = Query(None),
    linkRefNumber: Optional[List[str]] = Query(None)):
    resp = await controller.handle_fi_fetch(sessionId, fipId, linkRefNumber)
    return JSONResponse(content=resp)

def main(argv: List[str]) -> None:
    parser = argparse.ArgumentParser(description='The account aggregator (AA) service')
    parser.add_argument('--host', help='Service host', default='127.0.0.1')
    parser.add_argument('--port', help='Service port', type=int, default=8000)
    parser.add_argument('--id', help='The id of this service')
    parser.add_argument('--url-cr', help='Certificate registry (CR) service URL')
    parser.add_argument('--url-fiu', help='Financial information user (FIU) service URL', default='http://financial-information-user:8001/')
    parser.add_argument('--url-crypto', help='Crypto sidecar URL', default='http://crypto-sidecar:8283/')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose output')
    parser.add_argument('-d', '--debug', action='store_true', help='Debug output')
    args = parser.parse_args(argv)
    
    if not args.id:
        args.id = '{}-{}'.format("AA", str(uuid.uuid4()))
    
    # Setup the request processing controller.
    controller.config = args
    logger.verbose = args.verbose
    logger.debug = args.debug

    # Start the service: uvicorn aa.main:app --reload
    uvicorn.run(app, host=args.host, port=args.port)

if __name__ == '__main__':
    main(sys.argv[1:])
