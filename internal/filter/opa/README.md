# OPA-CCR Plugin
This OPA-CCR plugin makes it possible to delegate request/response allowed decisions to policies authored in Rego.

## How does it work?

In addition to the Envoy sidecar, your application pods will include the CCR sidecar which has the OPA engine embedded as a library. When the CCR sidecar receives API requests destined for your
microservice, it checks with OPA to decide if the request should be allowed and allows for policy to transform requests/responses.

This page covers how to write policies for the content of the requests and responses that are passed as policy input by the CCR sidecar. The CCR sidecar implements Envoy's
[External Processing
filter](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/ext_proc_filter) and in turn invokes a set of well known rules for policy evalution of the [ProcessingRequest](https://www.envoyproxy.io/docs/envoy/latest/api-v3/service/ext_proc/v3/external_processor.proto#envoy-v3-api-msg-service-ext-proc-v3-processingrequest) messages.


## Writing Policies
The CCR sidecar external processing filter implementation enables inspection of [4 types](https://www.envoyproxy.io/docs/envoy/latest/api-v3/service/ext_proc/v3/external_processor.proto#envoy-v3-api-msg-service-ext-proc-v3-processingrequest) of ProcessingRequest messages:  
- `ProcessingRequest_RequestHeaders`
- `ProcessingRequest_RequestBody`
- `ProcessingRequest_ResponseHeaders`
- `ProcessingRequest_ResponseBody`

Each of the above message type is mapped to a well known rule name by the CCR sidecar. The policy modules should implement the following four rules which would get invoked by the CCR sidecar on receipt of each of the above message types:
- `data.ccr.policy.on_request_headers`
- `data.ccr.policy.on_request_body`
- `data.ccr.policy.on_response_headers`
- `data.ccr.policy.on_response_body`


## Input Document
For each of the ProcessRequest message types above the [specified JSON mapping for protobuf](https://developers.google.com/protocol-buffers/docs/proto3#json)
is used for making the incoming `service.ext_proc.v3.ProcessingRequest` available as a JSON document in `input`. The [protojson.Marshal](https://pkg.go.dev/google.golang.org/protobuf/encoding/protojson#Marshal) API is used to convert the proto message to JSON,

For example, the input for `on_request_headers` looks like this:

```
{
    "requestHeaders": {
        "headers": {
            "headers": [
                {
                    "key": ":authority",
                    "value": "20.123.244.150"
                },
                {
                    "key": ":path",
                    "value": "/api/ccr/key"
                },
                {
                    "key": ":method",
                    "value": "GET"
                },
                {
                    "key": ":scheme",
                    "value": "http"
                },
                {
                    "key": "cache-control",
                    "value": "max-age=0"
                },
                {
                    "key": "upgrade-insecure-requests",
                    "value": "1"
                },
                {
                    "key": "accept-encoding",
                    "value": "gzip, deflate"
                },
                {
                    "key": "accept-language",
                    "value": "en-US,en;q=0.9"
                },
                {
                    "key": "x-forwarded-proto",
                    "value": "http"
                },
                {
                    "key": "x-request-id",
                    "value": "019d1417-017a-4697-842b-308e00fea796"
                },
                {
                    "key": "x-ccr-is-incoming",
                    "value": "true"
                }
            ]
        },
        "endOfStream": true
    },
    "teeType":"[none|sevsnpvm]",
    "context": <see Output Document for more details>
}
```
The input for `on_request_body` looks like this:
```
{
    "requestBody": {
        "body": "<bas64 encoded data>",
        "endOfStream": true
    },
    "teeType":"[none|sevsnpvm]",
    "context": <see Output Document for more details>
}
```
The input for `on_response_headers` looks like this:
```
{
    "responseHeaders": {
        "headers": {
            "headers": [
                {
                    "key": ":status",
                    "value": "200"
                },
                {
                    "key": "date",
                    "value": "Tue, 25 Oct 2022 06:21:03 GMT"
                },
                {
                    "key": "server",
                    "value": "envoy"
                },
                {
                    "key": "content-length",
                    "value": "1502"
                },
                {
                    "key": "content-type",
                    "value": "application/json"
                },
                {
                    "key": "x-envoy-upstream-service-time",
                    "value": "25"
                }
            ]
        }
    },
    "teeType":"[none|sevsnpvm]",
    "context": <see Output Document for more details>
}
```
The input for `on_response_body` looks like this:
```
{
    "responseBody": {
        "body": "<bas64 encoded data>",
        "endOfStream": true
    },
    "teeType":"[none|sevsnpvm]",
    "context": <see Output Document for more details>
}
```
In addition to the input carrying the request/response payload per above an additional readonly property named `teeType` is also sent by the CCR sidecar in the input payload. Its possible values are:
* `sevsnpvm`: if container is running in a AMD SEV-SNP environment.
* `none`: if container is running on non-confidential infra.

Any of the rules can use this information to adapt its logic if needed based on whether the instance is running on confidential compute or not.

## Output Document

When the CCR sidecar receives a policy decision, it expects a JSON object with the following fields:
* `allowed` (required): a boolean deciding whether or not the request is allowed
* `http_status` (optional): a number representing the HTTP status code. Can be used to set the HTTP response status code along with returning `allowed` as false.
* `body` (optional): the response body. If not specified then the original body remain in affect. Can be used to mutate the request/response body or say return an error message body along with `allowed` false  and `http_status` code error value.
* `context` (optional): Any request specific state that the policy wants to maintain across the 4 possible message types for the current HTTP request. This allows for carrying information across the 4 message types that one is expecting to see for an HTTP request that is being processed by the bidirectional GRPC stream handler in the CCR sidecar. Eg based on the values seen by the `on_request_headers` rule the rule's logic might stash some key/value pairs in the context that it then accesses in the `on_request_body` rule invocation for the HTTP message.  
The CCR sidecar saves any `context` from the output document and then passes it as-is as input into the next message. The context's lifetime is tied to the lifetime of the GRPC bidrectional stream for the HTTP message.
* `immediate_response` (optional): If specified as `true` then attempts to create a locally generated response, send it downstream, and stop processing additional filters and ignore any additional messages received from the remote server for this request or response. See [immediate_response](https://www.envoyproxy.io/docs/envoy/latest/api-v3/service/ext_proc/v3/external_processor.proto#envoy-v3-api-msg-service-ext-proc-v3-processingresponse) for more details.

## Examples

See the OPA policy implemented for the Confidential flow-based lending in the AA ecosystem scenario [here](../../../samples/aa-flow-based-lending/policies).

## Building and publishing the policy bundle

The Rego policy files need to be packaged as an OPA policy [bundle](https://www.openpolicyagent.org/docs/latest/management-bundles/) and published to an OCI registry (like ACR). See [Building and Publishing Policy Containers](https://www.openpolicyagent.org/docs/latest/management-bundles/#building-and-publishing-policy-containers) and the [sample publishing script](../../../build/publish-depa-policies-bundle.ps1) for more information.