package ccr.policy

import future.keywords

default on_response_headers = true

default on_request_headers = {
    "allowed": false,
    "http_status": 403,
    "body": {
        "code": "RequestNotAllowed",
        "message": "Failed ccr policy check: Requested API is not allowed"
    }
}

default on_request_body = {
    "allowed": false,
    "http_status": 403,
    "body": {
        "code": "RequestBodyNotAllowed",
        "message": "Failed ccr policy check: Requested API body is not allowed"
    }
}

default on_response_body = {
    "allowed": false,
    "http_status": 403,
    "body": {
        "code": "ResponseBodyNotAllowed",
        "message": "Failed ccr policy check: API's response body is not allowed"
    }
}

on_request_headers := response if {
    response := on_getkey
} else := response if {
    response := is_process
} else := response if {
    response := is_analyze_statements
}

on_request_body := response if {
    response := on_process_request
} else := response if {
    response := on_analyze_statements
}

on_response_body := response if {
    response := on_process_response
} else := response if {
    response := on_analyze_statements_response
}

# Example command line
# opa.exe eval -i input2.json -d . "data.ccr.policy.on_request_headers"