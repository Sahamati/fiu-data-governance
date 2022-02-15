# Confidential clean room (CCR) API

The CCR exposes an API surface that clients can use to interact with the CCR.

You can find the OpenAPI spec [here](ccr.yaml). The spec can be viewed in a nice format using an
OpenAPI viewer such as the [OpenAPI (Swagger)
Editor](https://marketplace.visualstudio.com/items?itemName=42Crunch.vscode-openapi) for Visual
Studio Code.

_Note: The CCR API surface is WIP and may change in the future as CCRs evolve and are evaluated
against more scenarios. We welcome your feedback and contributions._

## Data processing API

This is the API used by the CCR to confidentially process data.

The CCR exposes a `GET /api/ccr/key` API that can be used to get a new transaction id (`txnid`) as
well as corresponding public CCR key material (`KeyMaterial`). The `txnid` must be used when sending
a new data processing request to the CCR. The `KeyMaterial` must be used to encrypt the data, so
that the CCR can decrypt them upon receiving the corresponding data processing request.

This API returns a JSON object with the following fields (containing example values):
```json
{
  "ver": "1.0",
  "timestamp": "2018-12-06T11:39:57.153Z",
  "txnid": "3dd436f8-0747-4a8f-9001-375e419430be",
  "KeyMaterial": {
    "cryptoAlg": "ECDH",
    "curve": "Curve25519",
    "params": "string",
    "DHPublicKey": {
      "expiry": "2019-06-01T09:58:50.505Z",
      "Parameters": "string",
      "KeyValue": "string"
    },
    "nonce": "string"
  }
}
```

The CCR exposes a `POST /api/ccr/process` API that can be used to request for data to be processed
inside the CCR according to a given purpose and data principal's consent. The request must use a
transaction id (`txnid`) created by the CCR and encrypt one or more data using the public CCR key
material (`KeyMaterial`).

The body of the `POST` request must be a JSON object with the following fields:
```json
{
  "ver": "1.0",
  "timestamp": "2018-12-06T11:39:57.153Z",
  "txnid": "3dd436f8-0747-4a8f-9001-375e419430be",
  "payload": [
    {
      "id": "string",
      "data": [
        {
          "encryptedData": "string",
          "metadata": "{\"linkRefNumber\":\"XXXX-XXXX-XXXX\",\"maskedAccNumber\":\"XXXXXXXX4020\"}"
        }
      ],
      "KeyMaterial": {
        "cryptoAlg": "ECDH",
        "curve": "Curve25519",
        "params": "string",
        "DHPublicKey": {
          "expiry": "2019-06-01T09:58:50.505Z",
          "Parameters": "string",
          "KeyValue": "string"
        },
        "nonce": "string"
      }
    }
  ],
  "Consent": {
    "signature": "string",
    "consentArtefact": {
      "txnid": "0b811819-9044-4856-b0ee-8c88035f8858",
      "consentId": "XXXX-XXXX-XXXX-XXXX",
      "status": "ACTIVE",
      "createTimestamp": "2018-12-06T11:39:57.153Z",
      "signedConsent": "eyJhbGciOiJSUzI1NiIsImtpZCI6I",
      "ConsentUse": {
        "count": 1,
        "lastUseDateTime": "2018-12-06T11:39:57.153Z",
        "logUri": "string"
      }
    }
  }
}
```

If successful, this API returns a `200 OK` response containing a JSON object with the following
JSON fields including the `result` of the request:
```json
{
  "ver": "1.0",
  "timestamp": "2018-12-06T11:39:57.153Z",
  "txnid": "3dd436f8-0747-4a8f-9001-375e419430be",
  "result": "{\"score\":72}"
}
```

If the request will be handled asynchronously, the CCR returns a `202 Accepted` response with the
following JSON fields:
```json
{
  "ver": "1.0",
  "timestamp": "2018-12-06T11:39:57.153Z",
  "txnid": "3dd436f8-0747-4a8f-9001-375e419430be"
}
```

If the request is forbidden (e.g., due to not adhering to the enforced consent), the CCR returns
a `403 Forbidden` response with the following JSON fields:
```json
{
  "ver": "1.0",
  "timestamp": "2017-07-13T11:33:34.509Z",
  "txnid": "0b811819-9044-4856-b0ee-8c88035f8858'",
  "errorCode": "Forbidden",
  "errorMsg": "Error code specific error message."
}
```

The CCR exposes a `GET /api/ccr/process/{txnid}` API that can be used to retrieve the result of a
confidential processing request that has been handled _asynchronously_ by the CCR. The request must
use the same transaction id (`txnid`) created by the CCR and associated with the original `POST
/api/ccr/process` request.

If successful, this API returns a `200 OK` response containing a JSON object with the following
JSON fields including the `result` of the request:
```json
{
  "ver": "1.0",
  "timestamp": "2018-12-06T11:39:57.153Z",
  "txnid": "3dd436f8-0747-4a8f-9001-375e419430be",
  "result": "{\"score\":72}"
}
```

If the request is forbidden (e.g., due to not adhering to the enforced consent), the CCR returns
a `403 Forbidden` response with the following JSON fields:
```json
{
  "ver": "1.0",
  "timestamp": "2017-07-13T11:33:34.509Z",
  "txnid": "0b811819-9044-4856-b0ee-8c88035f8858'",
  "errorCode": "Forbidden",
  "errorMsg": "Error code specific error message."
}
```

If the request has not been handled yet, the CCR returns a `404 Not Found` response with the
following JSON fields:
```json
{
  "ver": "1.0",
  "timestamp": "2017-07-13T11:33:34.509Z",
  "txnid": "0b811819-9044-4856-b0ee-8c88035f8858'",
  "errorCode": "NotFound",
  "errorMsg": "Error code specific error message."
}
```

_Note: the asynchronous API is not yet supported in the current CCR prototype._
