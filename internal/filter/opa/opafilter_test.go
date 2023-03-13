package opa

import (
	"bytes"
	"strconv"
	"testing"

	ext_proc "github.com/envoyproxy/go-control-plane/envoy/service/ext_proc/v3"
	typev3 "github.com/envoyproxy/go-control-plane/envoy/type/v3"
	"github.com/microsoft/confidential-depa/internal/configuration"
	"github.com/microsoft/confidential-depa/internal/filter"
	"google.golang.org/protobuf/encoding/protojson"
)

const examplePathAllowedRequestHeader = `{
	"requestHeaders": {
        "headers": {
            "headers": [
                {
                    "key": ":path",
                    "value": "/api/action1"
                },
                {
                    "key": ":method",
                    "value": "GET"
                },
                {
                    "key": "x-ccr-is-incoming",
                    "value": "true"
                }
            ]
        },
        "endOfStream": true
    }
  }`

const examplePathDisallowedRequestHeader = `{
	"requestHeaders": {
        "headers": {
            "headers": [
                {
                    "key": ":path",
                    "value": "/api/action2"
                },
                {
                    "key": ":method",
                    "value": "GET"
                },
                {
                    "key": "x-ccr-is-incoming",
                    "value": "true"
                }
            ]
        },
        "endOfStream": true
    }
  }`

const exampleMethodDisallowedRequestHeader = `{
	"requestHeaders": {
        "headers": {
            "headers": [
                {
                    "key": ":path",
                    "value": "/api/action1"
                },
                {
                    "key": ":method",
                    "value": "POST"
                },
                {
                    "key": "x-ccr-is-incoming",
                    "value": "true"
                }
            ]
        },
        "endOfStream": true
    }
  }`

const exampleMutationRequestBody = `{
	"requestBody": {
        "body": "aW5wdXQgYm9keQ==",
        "endOfStream": true
    }
  }`

const exampleMutationResponseBody = `{
	"responseBody": {
        "body": "aW5wdXQgYm9keQ==",
        "endOfStream": true
    }
  }`

func Test_RequestHeader_PathAllowed(t *testing.T) {
	f, err := testOpaFilter()
	if err != nil {
		t.Fatal(err)
	}

	var req ext_proc.ProcessingRequest
	if err := protojson.Unmarshal([]byte(examplePathAllowedRequestHeader), &req); err != nil {
		panic(err)
	}

	resp := f.OnRequestHeaders(&req)
	var ok bool
	hr, ok := resp.Response.(*ext_proc.ProcessingResponse_RequestHeaders)
	if !ok {
		t.Fatalf("Expected response type to be %T but got: %v", hr, resp)
	}

	if hr.RequestHeaders.Response.Status != ext_proc.CommonResponse_CONTINUE {
		t.Fatal("Expected request to be allowed but got:", resp)
	}
}

func Test_RequestHeader_PathDisallowed(t *testing.T) {
	f, err := testOpaFilter()
	if err != nil {
		t.Fatal(err)
	}

	var req ext_proc.ProcessingRequest
	if err := protojson.Unmarshal([]byte(examplePathDisallowedRequestHeader), &req); err != nil {
		panic(err)
	}

	resp := f.OnRequestHeaders(&req)
	var ok bool
	ir, ok := resp.Response.(*ext_proc.ProcessingResponse_ImmediateResponse)
	if !ok {
		t.Fatalf("Expected response type to be %T but got: %v", ir, resp)
	}

	expectedCode := typev3.StatusCode_Forbidden
	if ir.ImmediateResponse.Status.Code != expectedCode {
		t.Fatalf("Expected status code %v but got %v", expectedCode, ir.ImmediateResponse.Status.Code)
	}
}

func Test_RequestHeader_MethodDisallowed(t *testing.T) {
	f, err := testOpaFilter()
	if err != nil {
		t.Fatal(err)
	}

	var req ext_proc.ProcessingRequest
	if err := protojson.Unmarshal([]byte(exampleMethodDisallowedRequestHeader), &req); err != nil {
		panic(err)
	}

	resp := f.OnRequestHeaders(&req)
	var ok bool
	ir, ok := resp.Response.(*ext_proc.ProcessingResponse_ImmediateResponse)
	if !ok {
		t.Fatalf("Expected response type to be %T but got: %v", ir, resp)
	}

	expectedCode := typev3.StatusCode_Forbidden
	if ir.ImmediateResponse.Status.Code != expectedCode {
		t.Fatalf("Expected status code %v but got %v", expectedCode, ir.ImmediateResponse.Status.Code)
	}
}

func Test_RequestBody_ResponseMutationSuccess(t *testing.T) {
	f, err := testOpaFilter()
	if err != nil {
		t.Fatal(err)
	}

	// Send a RequestHeader message first as that is a pre-req for the RequestBody message.
	var req ext_proc.ProcessingRequest
	if err := protojson.Unmarshal([]byte(examplePathAllowedRequestHeader), &req); err != nil {
		panic(err)
	}

	resp := f.OnRequestHeaders(&req)
	var ok bool
	hr, ok := resp.Response.(*ext_proc.ProcessingResponse_RequestHeaders)
	if !ok {
		t.Fatalf("Expected response type to be %T but got: %v", hr, resp)
	}

	if hr.RequestHeaders.Response.Status != ext_proc.CommonResponse_CONTINUE {
		t.Fatal("Expected request to be allowed but got:", resp)
	}

	// Now send the RequestBody message.
	if err := protojson.Unmarshal([]byte(exampleMutationRequestBody), &req); err != nil {
		panic(err)
	}

	resp = f.OnRequestBody(&req)
	br, ok := resp.Response.(*ext_proc.ProcessingResponse_RequestBody)
	if !ok {
		t.Fatalf("Expected response type to be %T but got: %v", hr, resp)
	}

	if br.RequestBody.Response.Status != ext_proc.CommonResponse_CONTINUE {
		t.Fatal("Expected request to be allowed but got:", resp)
	}

	if br.RequestBody.Response.BodyMutation.Mutation == nil {
		t.Fatal("Expected mutation response but got nil mutation in response:", resp)
	}

	bm, ok := br.RequestBody.Response.BodyMutation.Mutation.(*ext_proc.BodyMutation_Body)
	if !ok {
		t.Fatalf("Expected response type to be %T but got: %v", hr, resp)
	}

	expectedBody := "output body"
	if !bytes.Equal(bm.Body, []byte(expectedBody)) {
		t.Fatalf("Expected response body to be %q but got %q", expectedBody, string(bm.Body))
	}

	if len(br.RequestBody.Response.HeaderMutation.SetHeaders) != 1 {
		t.Fatalf("Expected one header to get added but got: %v", br.RequestBody.Response.HeaderMutation.SetHeaders)
	}

	hv := br.RequestBody.Response.HeaderMutation.SetHeaders[0]
	expectedContentLengthKey := "Content-Length"
	if hv.Header.Key != expectedContentLengthKey {
		t.Fatalf("Expected header key %v but got: %v", expectedContentLengthKey, hv.Header.Key)
	}

	expectedContentLength := strconv.Itoa(len(expectedBody))
	if hv.Header.Value != expectedContentLength {
		t.Fatalf("Expected content length header value %v but got: %v", expectedContentLength, hv.Header.Value)
	}
}

func Test_ResponseBody_ResponseMutationSuccess(t *testing.T) {
	f, err := testOpaFilter()
	if err != nil {
		t.Fatal(err)
	}

	// Send a RequestHeader message first as that is a pre-req for the ResponseBody message.
	var req ext_proc.ProcessingRequest
	if err := protojson.Unmarshal([]byte(examplePathAllowedRequestHeader), &req); err != nil {
		panic(err)
	}

	resp := f.OnRequestHeaders(&req)
	var ok bool
	hr, ok := resp.Response.(*ext_proc.ProcessingResponse_RequestHeaders)
	if !ok {
		t.Fatalf("Expected response type to be %T but got: %v", hr, resp)
	}

	if hr.RequestHeaders.Response.Status != ext_proc.CommonResponse_CONTINUE {
		t.Fatal("Expected request to be allowed but got:", resp)
	}

	// Now send the ResponseBody message.
	if err := protojson.Unmarshal([]byte(exampleMutationResponseBody), &req); err != nil {
		panic(err)
	}

	resp = f.OnResponseBody(&req)
	br, ok := resp.Response.(*ext_proc.ProcessingResponse_ResponseBody)
	if !ok {
		t.Fatalf("Expected response type to be %T but got: %v", hr, resp)
	}

	if br.ResponseBody.Response.Status != ext_proc.CommonResponse_CONTINUE {
		t.Fatal("Expected request to be allowed but got:", resp)
	}

	if br.ResponseBody.Response.BodyMutation.Mutation == nil {
		t.Fatal("Expected mutation response but got nil mutation in response:", resp)
	}

	bm, ok := br.ResponseBody.Response.BodyMutation.Mutation.(*ext_proc.BodyMutation_Body)
	if !ok {
		t.Fatalf("Expected response type to be %T but got: %v", hr, resp)
	}

	expectedBody := "output body"
	if !bytes.Equal(bm.Body, []byte(expectedBody)) {
		t.Fatalf("Expected response body to be %q but got %q", expectedBody, string(bm.Body))
	}

	if len(br.ResponseBody.Response.HeaderMutation.SetHeaders) != 1 {
		t.Fatalf("Expected one header to get added but got: %v", br.ResponseBody.Response.HeaderMutation.SetHeaders)
	}

	hv := br.ResponseBody.Response.HeaderMutation.SetHeaders[0]
	expectedContentLengthKey := "Content-Length"
	if hv.Header.Key != expectedContentLengthKey {
		t.Fatalf("Expected header key %v but got: %v", expectedContentLengthKey, hv.Header.Key)
	}

	expectedContentLength := strconv.Itoa(len(expectedBody))
	if hv.Header.Value != expectedContentLength {
		t.Fatalf("Expected content length header value %v but got: %v", expectedContentLength, hv.Header.Value)
	}
}

func testOpaFilter() (filter.HttpFilter, error) {
	module := `
		package ccr.policy

		import future.keywords

		default on_request_headers = false

		on_request_headers := response {
			some h1 in input.requestHeaders.headers.headers
			h1.key == ":path"
			h1.value == "/api/action1"

			some h2 in input.requestHeaders.headers.headers
			h2.key == ":method"
			h2.value == "GET"
			response := {
				"allowed": true,
				"context": {
					"path": "/api/action1"
				}
			}
		}

		default on_request_body = false

		on_request_body := response {
			input.context.path == "/api/action1"
			input.requestBody.body == "aW5wdXQgYm9keQ=="
			response := {
				"allowed": true,
				"body": "output body"
			}
		}

		default on_response_headers = true

		default on_response_body = true

		on_response_body := response {
			input.context.path == "/api/action1"
			input.responseBody.body == "aW5wdXQgYm9keQ=="
			response := {
				"allowed": true,
				"body": "output body"
			}
		}
		`

	ff, err := NewHttpFilterFactory(configuration.PolicyEngine{
		Modules: map[string]string{
			"example.rego": module,
		},
	})
	if err != nil {
		return nil, err
	}

	return ff.CreateFilter(), nil
}
