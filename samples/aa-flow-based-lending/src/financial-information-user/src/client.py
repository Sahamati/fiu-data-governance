import json
import requests

import logger as logger

from datetime import datetime
from typing import Mapping

REQUEST_HEADERS = {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
}

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

def post_json_request(endpoint: str, path: str, json: dict, headers: dict = {}):
    logger.log_http_request('POST', path, endpoint)
    t0 = datetime.now()
    headers.update(REQUEST_HEADERS)
    status, resp = _do_post_json_request(_make_url(endpoint, path), json, headers)
    t1 = datetime.now()
    latency_ms = (t1-t0).total_seconds() * 1000
    logger.log_http_response('POST', latency_ms)
    return status, resp.decode("utf-8")

def get_json_request(endpoint: str, path: str, query: dict, headers: dict = {}):
    logger.log_http_request('GET', path, endpoint)
    t0 = datetime.now()
    headers.update(REQUEST_HEADERS)
    status, resp = _do_get_json_request(_make_url(endpoint, path), query, headers)
    t1 = datetime.now()
    latency_ms = (t1-t0).total_seconds() * 1000
    logger.log_http_response('GET', latency_ms)
    return status, resp.decode("utf-8")

def _do_post_json_request(url: str, json: dict, headers: Mapping[str,str]):
    response = requests.post(url, headers=headers, json=json, auth=None, verify=False)
    try:
        response.raise_for_status()
    except requests.HTTPError:
        raise RequestError(response.status_code, response.text)
    return response.status_code, response.content

def _do_get_json_request(url: str, query: dict, headers: Mapping[str,str]):
    if query:
        response = requests.get(url, headers=headers, params=query, auth=None, verify=False)
    else:
        response = requests.get(url, headers=headers, auth=None, verify=False)
    try:
        response.raise_for_status()
    except requests.HTTPError:
        raise RequestError(response.status_code, response.text)
    return response.status_code, response.content

def _make_url(url: str, path: str) -> str:
    if url[-1] == '/':
        url = url[:-1]
    if path[0] == '/':
        path = path[1:]
    return url + '/' + path
