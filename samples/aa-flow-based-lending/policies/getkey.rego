package ccr.policy

import future.keywords

on_getkey = result {
    get_method == "GET"
    get_path == "/api/ccr/key"
    txnid := uuid.rfc4122("") # TODO (gsinha): Is passing "" ok?
    key := gen_keypair
    token := get_attestation_token(input.teeType, key.public_key_material)
    t := set_key(txnid, key)
    result := {
        "allowed": true,
        "immediate_response": true,
        "body": {
            "ver": "0.0.1",
            "timestamp": get_current_timestamp,
            "txnid": t,
            "KeyMaterial": {
                "cryptoAlg" : key.public_key_material.cryptoAlg,
                "curve": "Curve25519",
                "params": "cipher=AES/GCM/NoPadding;KeyPairGenerator=ECDH",
                "DHPublicKey": {
                    "expiry" : key.public_key_material.DHPublicKey.expiry,
                    "Parameters" : key.public_key_material.DHPublicKey.Parameters,
                    "KeyValue" : key.public_key_material.DHPublicKey.KeyValue,
                },
                "Nonce": gen_once,
            },
            "token": token
        },
        "context": create_context
    }
}

get_attestation_token(teeType, runtimeData) := token if {
    teeType == "none"
    print("Not invoking the skr sidecar to generate attestation token as 'skip_attestation_token' is true")
    token = {}
} else := token if {
    print("Invoking the skr sidecar to generate attestation token")
    runtimeJson := json.marshal(runtimeData)
    b64RuntimeData := base64.encode(runtimeJson)
    attestationRequest := {
        "maa_endpoint": data.local.skr_sidecar.maa_endpoint,
        "runtime_data": b64RuntimeData,
    }

    endpoint := sprintf("http://%s:%d/attest/maa", [data.host, data.local.skr_sidecar.port])
    response := http.send({
        "method": "post",
        "url": endpoint,
        "raise_error": false,
        "headers": { "Content-Type": "application/json" },
        "body": attestationRequest})
    print(sprintf("POST /attest/maa response: %v", [response]))
    response.status_code == 200
    token := response.body.token
}
# opa.exe eval -i input2.json -d example2.rego -d helpers.rego "data.ccr.policy.test_set_key" --data data.json