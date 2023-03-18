import argparse
import os
import sys
import uvicorn

import controller as controller
import logger as logger

from fastapi import FastAPI, Request, Header
from typing import List

app = FastAPI()

# The entry point to the sandboxed by the CCR business logic.
@app.post("/api/ccr/process")
async def process_fi(request: Request, x_jws_signature: str = Header(None)):
    request = await request.json()
    # Handle the request.
    return controller.handle_scoring_request(request)

def main(argv: List[str]) -> None:
    parser = argparse.ArgumentParser(description='The business rule engine (BRE) service')
    parser.add_argument('--host', help='Service host', default='localhost')
    parser.add_argument('--port', help='Service port', type=int, default=80)
    parser.add_argument('--url-sa', help='Statement analysis (SA) service URL', default='http://statement-analysis:8000/')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose output')
    parser.add_argument('-d', '--debug', action='store_true', help='Debug output')
    args = parser.parse_args(argv)

    # Sanity check and process arguments.
    args.url_sa = os.environ.get('SA_URL', args.url_sa)

    # Setup the request processing controller.
    controller.config = args
    logger.verbose = args.verbose
    logger.debug = args.debug

    # Start the service: uvicorn bre.main:app --reload
    uvicorn.run(app, host=args.host, port=args.port)

if __name__ == '__main__':
    main(sys.argv[1:])
