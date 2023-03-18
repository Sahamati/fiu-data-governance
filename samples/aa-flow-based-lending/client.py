import argparse
import json
import requests
import sys

from datetime import datetime
from requests.auth import AuthBase
from typing import List, Mapping, Optional

REQUEST_HEADERS = {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
}

AA_SETUP_REQUEST_URL_PATH = 'setup/statements'
FIU_SETUP_BRE_INFO_URL_PATH = 'setup/bre-info'
AA_SETUP_CR_INFO_URL_PATH = 'setup/cr-info'
FIU_REQUEST_URL_PATH = 'request'

class RequestError(Exception):
    def __init__(self, status_code: int, response_text: str):
        self.status_code = status_code
        self.response_text = response_text
        try:
            obj = json.loads(response_text)
            self.error_code = obj['error_code']
            self.error_message = obj['error_message']
        except json.JSONDecodeError:
            self.error_code = "N/A"
            self.error_message = response_text
        super().__init__(f"HTTP status={status_code}, error code={self.error_code}, error message={self.error_message}")

def process_req(args) -> None:
    if args.fi:
        with open(args.fi) as fp:
            data = json.load(fp)
    else:
        raise NotImplementedError

    print('Sending user FI data to AA:')
    print(data)
    send_post_json_request(args.aa_url, AA_SETUP_REQUEST_URL_PATH, data)

    if args.consent:
        with open(args.consent) as fp:
            data = json.load(fp)
    else:
        raise NotImplementedError

    print('Sending business rule engine URL to FIU:')
    print(args.bre_url)
    send_post_json_request(args.fiu_url, FIU_SETUP_BRE_INFO_URL_PATH, { 'url': args.bre_url })
    print('Sending certificate registry URL to AA:')
    print(args.cr_url)
    send_post_json_request(args.aa_url, AA_SETUP_CR_INFO_URL_PATH, { 'url': args.cr_url })
    print('Sending user consent to FIU:')
    print(data)
    send_post_json_request(args.fiu_url, FIU_REQUEST_URL_PATH, data)

def send_post_json_request(url, url_path, json):
    if url[-1] != '/':
        url += '/'
    print(f'Sending POST request')
    t0 = datetime.now()
    resp_msg = do_post_json_request(url + url_path, json, REQUEST_HEADERS, None)
    t1 = datetime.now()
    latency_ms = (t1-t0).total_seconds() * 1000
    print(f'Received response after {latency_ms:.1f} ms')
    return resp_msg

def do_post_json_request(url: str, json: dict, headers: Mapping[str,str], auth: Optional[AuthBase]):
    response = requests.post(url, headers=headers, json=json, auth=auth)
    try:
        response.raise_for_status()
    except requests.HTTPError:
        raise RequestError(response.status_code, response.text)
    return response.content

def main(argv: List[str]) -> None:
    parser = argparse.ArgumentParser(description='Test client for sending data processing and inference requests')
    parser.add_argument('--fi', help='User FI data in JSON format')
    parser.add_argument('--consent', help='User consent file in JSON format')
    parser.add_argument('--aa-url', help='AA service URL', default='http://localhost:8000/')
    parser.add_argument('--fiu-url', help='FIU service URL', default='http://localhost:8011/')
    parser.add_argument('--bre-url', help='Business rule engine (BRE) service URL')
    parser.add_argument('--cr-url', help='Certificate registry (CR) service URL')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose output')
    args = parser.parse_args(argv)

    if not args.fi:
        parser.error('Not specified a user FI data file (in JSON format) for the AA request to AA')
    if not args.consent:
        parser.error('Not specified a user consent file (in JSON format) for the FI request to FIU')
    if not args.bre_url:
        parser.error('Not specified a business rule engine (BRE) service URL')
    if not args.cr_url:
        parser.error('Not specified a certificate registry (CR) service URL')

    process_req(args)

if __name__ == '__main__':
    main(sys.argv[1:])
