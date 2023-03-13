package ccr.policy

import future.keywords

is_process = result {
    get_method == "POST"
    get_path == "/api/ccr/process"
    result := {
        "allowed": true,
        "context": create_context
    }
}

on_process_request = result {
    input.context.method == "POST"
    input.context.path == "/api/ccr/process"
    print("Validating compliance of incoming request.")
    request := json.unmarshal(base64.decode(input.requestBody.body))

    # The policy allows an incoming request if all consent checks pass.
    violations := deny_incoming_request with input as request
    count(violations) == 0

    result := {
        "allowed": true,
        "body": decrypt_request_payload(request)
    }
}

on_process_response = result {
    input.context.method == "POST"
    input.context.path == "/api/ccr/process"
    print("Validating compliance of outgoing response.")
    response := json.unmarshal(base64.decode(input.responseBody.body))

    # The policy allows an outgoing response if all consent checks pass.
    violations := deny_outgoing_response with input as response
    count(violations) == 0

    result := { "allowed": true }
}

deny_incoming_request["Failed policy check: invalid consent signature"] {
    not is_consent_signature_valid
}

deny_incoming_request["Failed policy check: consent is not active"] {
    not is_consent_active
}

deny_outgoing_response["Failed egress policy check: response is not compliant"] {
    not is_response_compliant
}

# Checks if the consent signature is valid.
is_consent_signature_valid = true {
    print("Verifying consent signature.")
    aaEntityInfo := get_aa_entityinfo
    # Decode consent signature.
    [header, consent_detail, _] := io.jwt.decode(input.Consent.consentArtefact.signedConsent)
    # Find index of aa_info for data_provider specified in payload of the signed consent.
    aaEntityInfo.entities[k].entityinfo.id == consent_detail.DataProvider.id
    # Extract corresponding certs.
    certificate := aaEntityInfo.entities[k].entityinfo.certificate
    # Create jwks from certs.
    jwks = json.marshal({ "keys": [certificate]})
    # Verify signature.
    is_signature_verified(input.Consent.consentArtefact.signedConsent, jwks)
}

# Checks consent start and expiry dates against current time.
is_consent_active = true {
    trace("Checking if consent is active for this period.")
    # Extract the consent detail from the signed consent.
    [header, consent_detail, _] := io.jwt.decode(input.Consent.consentArtefact.signedConsent)
    # Parse dates from ISO to ns.
    consent_start := time.parse_rfc3339_ns(consent_detail.consentStart)
    consent_expiry := time.parse_rfc3339_ns(consent_detail.consentExpiry)
    # Get current time in ns.
    current_time := time.now_ns()
    # Compare current time with consent start and expiry.
    is_value_in_range(current_time, consent_start, consent_expiry)
}

# Checks if the response is compliant.
is_response_compliant = true {
    trace("Checking if response is compliant.")
    # All checks must pass for the response to be compliant.
    input_json := json.marshal(input)
    is_expected_num_json_fields(input_json, 4)
    is_valid_version(input.ver)
    is_valid_guid(input.txnid)
    is_timestamp_valid(input.timestamp)
    is_value_in_range(input.score, 1, 100)
}

decrypt_request_payload(request) := response if {
    payload := decrypt_payload(request.payload, request.txnid)
    response := {
        "ver": request.ver,
        "timestamp": request.timestamp,
        "txnid": request.txnid,
        "payload": payload,
        "Consent": request.Consent
    }
}

decrypt_payload(payload, txnid) := result if {
    print("Decrypting the request payload")
    privateKey := get_key(txnid)
    result = [ payload_element | payload_element := process_payload_element(payload[i], privateKey) ]
}

process_payload_element(payload, privateKey) := { 
	"id" : payload.id,
	"data" : [data_element |
         data_element := process_data_element(payload.data[i], privateKey, payload.KeyMaterial)],
    "KeyMaterial" : payload.KeyMaterial
}

process_data_element(data_element, privateKey, publicKey) := d if {
    nonce := gen_once
    d := {
        "encryptedData" : decrypt_data(data_element.encryptedData, privateKey, publicKey, nonce),
        "metadata" : data_element.metadata
    }
}

get_aa_entityinfo := entityinfo if {
    print(sprintf("Asking for AA entity info from %s", [data.services.aa_cert_registry.uri]))
    endpoint := sprintf("%s/entityInfo/AA", [data.services.aa_cert_registry.uri])
    response := http.send({
        "method": "get",
        "url": endpoint,
        "raise_error": false,
        "headers": { "Content-Type": "application/json" }})
    print(sprintf("key provider GET /entityInfo/AA response: %v", [response]))
    response.status_code == 200
    entityinfo := { "entities": response.body }
}

# opa.exe eval -i input2.json -d example2.rego -d helpers.rego "data.ccr.policy.test_set_key" --data data.json