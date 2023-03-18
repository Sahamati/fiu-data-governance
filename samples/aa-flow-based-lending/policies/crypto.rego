package ccr.policy

import future.keywords

gen_keypair := key if {
    print("Invoking the crypto sidecar to generate key pair")
    endpoint := sprintf("http://%s:%d/ecc/v1/generateKey", [data.host, data.local.crypto_sidecar.port])
    response := http.send({"method": "get", "url": endpoint, "raise_error": false})
    print(sprintf("GET /ecc/v1/generateKey response: %v", [response]))
    response.status_code == 200 # TODO (gsinha): Handle error response and also ErrorInfo on 200.
    forwardSecrecyKeyGenResponse := json.unmarshal(response.raw_body)
    key := {
        "value" : forwardSecrecyKeyGenResponse.privateKey,
        "public_key_material" : forwardSecrecyKeyGenResponse.KeyMaterial
    }
}

decrypt_data(base64data, privateKey, publicKey, nonce) := decrypted_data if {
    forwardSecrecyDecryptionRequest := {
		"base64Data":           base64data,
		"base64RemoteNonce":    publicKey.Nonce,
		"base64YourNonce":      nonce,
		"ourPrivateKey":        privateKey.value,
		"remoteKeyMaterial": {
			"cryptoAlg":    publicKey.cryptoAlg,
			"curve":        publicKey.curve,
			"params":       publicKey.params,
			"DHPublicKey": {
				"expiry":       publicKey.DHPublicKey.expiry,
				"Parameters":   publicKey.DHPublicKey.Parameters,
				"KeyValue":     publicKey.DHPublicKey.KeyValue,
			},
		},
    }
    print("Invoking the crypto sidecar to decrypt")
    endpoint := sprintf("http://%s:%d/ecc/v1/decrypt", [data.host, data.local.crypto_sidecar.port])
    response := http.send({
        "method": "post",
        "url": endpoint,
        "raise_error": false,
        "headers": { "Content-Type": "application/json" },
        "body": forwardSecrecyDecryptionRequest})

    response.status_code == 200 # TODO (gsinha): Handle error response and also ErrorInfo on 200.
    forwardSecrecyCryptoResponse := json.unmarshal(response.raw_body)
    decrypted_data := forwardSecrecyCryptoResponse.base64Data
}