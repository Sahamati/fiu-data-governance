package filter

import (
	pb "github.com/envoyproxy/go-control-plane/envoy/service/ext_proc/v3"
	typev3 "github.com/envoyproxy/go-control-plane/envoy/type/v3"
)

type Header string

const (
	Method        Header = ":method"
	Path          Header = ":path"
	Authority     Header = ":authority"
	CcrIsIncoming Header = "x-ccr-is-incoming"
)

// Creates a request headers proxy response containing the specified mutated headers as payload.
func CreateRequestHeadersProxyResponse(
	status pb.CommonResponse_ResponseStatus,
	headerMutation *pb.HeaderMutation,
	bodyMutation *pb.BodyMutation) *pb.ProcessingResponse {
	rhq := createMutationResponse(status, headerMutation, bodyMutation)
	resp := &pb.ProcessingResponse{
		Response: &pb.ProcessingResponse_RequestHeaders{
			RequestHeaders: &pb.HeadersResponse{
				Response: rhq,
			},
		},
	}

	return resp
}

// Creates a request body proxy response containing the specified mutated body as payload.
func CreateRequestBodyProxyResponse(
	status pb.CommonResponse_ResponseStatus,
	headerMutation *pb.HeaderMutation,
	bodyMutation *pb.BodyMutation) *pb.ProcessingResponse {
	rhq := createMutationResponse(status, headerMutation, bodyMutation)
	resp := &pb.ProcessingResponse{
		Response: &pb.ProcessingResponse_RequestBody{
			RequestBody: &pb.BodyResponse{
				Response: rhq,
			},
		},
	}

	return resp
}

// Creates a response body proxy response containing the specified mutated body as payload.
func CreateResponseBodyProxyResponse(
	status pb.CommonResponse_ResponseStatus,
	headerMutation *pb.HeaderMutation,
	bodyMutation *pb.BodyMutation) *pb.ProcessingResponse {
	rhq := createMutationResponse(status, headerMutation, bodyMutation)
	resp := &pb.ProcessingResponse{
		Response: &pb.ProcessingResponse_ResponseBody{
			ResponseBody: &pb.BodyResponse{
				Response: rhq,
			},
		},
	}

	return resp
}

// Creates a response headers proxy response containing the specified mutated headers as payload.
func CreateResponseHeadersProxyResponse(
	status pb.CommonResponse_ResponseStatus,
	headerMutation *pb.HeaderMutation,
	bodyMutation *pb.BodyMutation) *pb.ProcessingResponse {
	rhq := createMutationResponse(status, headerMutation, bodyMutation)
	resp := &pb.ProcessingResponse{
		Response: &pb.ProcessingResponse_ResponseHeaders{
			ResponseHeaders: &pb.HeadersResponse{
				Response: rhq,
			},
		},
	}

	return resp
}

// Creates an immediate proxy response with the specified status and payload. Immediate
// responses are used by the CCR proxy to send a response to the client, without having
// to go through the business logic container.
func CreateImmediateProxyResponse(
	status typev3.StatusCode, body string, details string) *pb.ProcessingResponse {
	response := &pb.ProcessingResponse_ImmediateResponse{
		ImmediateResponse: &pb.ImmediateResponse{
			Status: &typev3.HttpStatus{
				Code: status,
			},
			Body:    body,
			Details: details,
		},
	}

	return &pb.ProcessingResponse{
		Response: response,
	}
}

// Creates an immediate error proxy response.
func CreateErrorProxyResponse(
	status typev3.StatusCode, details string) *pb.ProcessingResponse {
	return CreateImmediateProxyResponse(status, "", details)
}

// Creates a response that notifies the proxy how to mutate a request or response.
func createMutationResponse(
	status pb.CommonResponse_ResponseStatus,
	headerMutation *pb.HeaderMutation,
	bodyMutation *pb.BodyMutation) *pb.CommonResponse {
	rhq := &pb.CommonResponse{
		Status:          status,
		HeaderMutation:  headerMutation,
		BodyMutation:    bodyMutation,
		Trailers:        nil,
		ClearRouteCache: false,
	}

	return rhq
}

func ExtractHeader(key Header, headers *pb.ProcessingRequest_RequestHeaders) string {
	for _, n := range headers.RequestHeaders.Headers.Headers {
		if n.Key == string(key) {
			return n.Value
		}
	}

	return ""
}
