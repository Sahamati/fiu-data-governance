import argparse
import sys
import uvicorn

import controller as controller
import logger as logger

from fastapi import FastAPI, Request, Header
from fastapi.responses import JSONResponse
from typing import List

app = FastAPI()

# Stores the specified AA certificate.
@app.post("/certificate/AA")
async def store_certificate(request: Request):
    certificate = await request.json()
    controller.certificate = certificate
    return JSONResponse(content={
        "timestamp": controller.get_current_timestamp()
    })

# Returns the AA entity info.
@app.get("/entityInfo/AA")
async def get_aa_entity_info(x_jws_signature: str = Header(None)):
    # Handle the request.
    return controller.handle_aa_entity_info_request()

def main(argv: List[str]) -> None:
    parser = argparse.ArgumentParser(description='The certificate registry (CR) service')
    parser.add_argument('--host', help='Service host', default='localhost')
    parser.add_argument('--port', help='Service port', type=int, default=80)
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose output')
    parser.add_argument('-d', '--debug', action='store_true', help='Debug output')
    args = parser.parse_args(argv)

    # Setup the request processing controller.
    logger.verbose = args.verbose
    logger.debug = args.debug

    # Start the service: uvicorn sa.main:app --reload
    uvicorn.run(app, host=args.host, port=args.port)   

if __name__ == '__main__':
    main(sys.argv[1:])
