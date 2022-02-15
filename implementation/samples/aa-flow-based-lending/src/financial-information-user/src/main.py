import argparse
import asyncio
import sys
import uvicorn

import controller as controller
import logger as logger

from fastapi import FastAPI, Request, Header
from fastapi.responses import JSONResponse
from typing import List

app = FastAPI()

# Sets the business rule engine URL for the workflow of this sample.
@app.post("/setup/bre-info")
async def setup_bre_url(request: Request):
    request = await request.json()
    controller.configure_bre_info(request)

# Processes a new request (starts the workflow of this sample).
@app.post("/request")
async def process_request(request: Request):
    request = await request.json()
    asyncio.ensure_future(controller.start_workflow(request))

@app.post("/Consent/Notification")
async def process_consent_notification(request: Request, x_jws_signature: str = Header(None)):
    request = await request.json()
    # Create async task to handle the request.
    asyncio.ensure_future(controller.handle_consent_notification(request))
    return JSONResponse(content={
        "ver": "1.0",
        "timestamp": controller.get_current_timestamp(),
        "txnid": request["txnid"],
        "response": "OK"
    })

@app.post("/FI/Notification")
async def process_fi_notification(request: Request, x_jws_signature: str = Header(None)):
    request = await request.json()
    # Create async task to handle the request.
    asyncio.ensure_future(controller.handle_fi_notification(request))
    return JSONResponse(content={
        "ver": "1.0",
        "timestamp": controller.get_current_timestamp(),
        "txnid": request["txnid"],
        "response": "OK"
    })

def main(argv: List[str]) -> None:
    # Parse the command line arguments.
    parser = argparse.ArgumentParser(description='The business rule engine (BRE) frontend')
    parser.add_argument('--host', help='Service host', default='127.0.0.1')
    parser.add_argument('--port', help='Service port', type=int, default=8001)
    parser.add_argument('--url-bre', help='Business rule engine (BRE) service URL', default='http://127.0.0.1:8888/')
    parser.add_argument('--url-aa', help='Account aggregator (AA) service URL', default='http://account-aggregator:8000/')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose output')
    parser.add_argument('-d', '--debug', action='store_true', help='Debug output')
    args = parser.parse_args(argv)

    # Setup the request processing controller.
    controller.config = args
    logger.verbose = args.verbose
    logger.debug = args.debug

    # Start the service: uvicorn fiu.main:app --reload
    uvicorn.run(app, host=args.host, port=args.port)

if __name__ == '__main__':
    main(sys.argv[1:])
