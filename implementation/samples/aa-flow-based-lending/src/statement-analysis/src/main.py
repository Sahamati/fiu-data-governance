import argparse
import sys
import uvicorn

import controller as controller
import logger as logger

from fastapi import FastAPI, Request, Header
from typing import List

app = FastAPI()

@app.post("/AnalyzeStatements")
async def analyze_statements(request: Request, x_jws_signature: str = Header(None)):
    request = await request.json()
    # Handle the request.
    return controller.handle_analyze_statements(request)

def main(argv: List[str]) -> None:
    parser = argparse.ArgumentParser(description='The statement analysis (SA) service')
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
