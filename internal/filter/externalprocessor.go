package filter

import (
	"fmt"
	"io"

	log "github.com/sirupsen/logrus"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	pb "github.com/envoyproxy/go-control-plane/envoy/service/ext_proc/v3"
	typev3 "github.com/envoyproxy/go-control-plane/envoy/type/v3"
)

func NewExternalProcessorServer(f HttpFilterFactory) pb.ExternalProcessorServer {
	return &externalProcessor{
		filterFactory: f,
	}
}

type externalProcessor struct {
	filterFactory HttpFilterFactory
}

func (s *externalProcessor) Process(srv pb.ExternalProcessor_ProcessServer) error {

	// Create a new httpFilter instance for processing this proxy request stream.
	httpFilter := s.filterFactory.CreateFilter()
	ctx := srv.Context()
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		// Process the gRPC request asynchronously by connecting to its bi-directional stream.
		req, err := srv.Recv()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return status.Errorf(codes.Unknown, "cannot receive stream request: %v", err)
		}

		// Handle the next proxy request from the stream.
		resp := handleProxyRequest(httpFilter, req)

		if err := srv.Send(resp); err != nil {
			log.Errorf("send error %v", err)
			return status.Errorf(codes.Unknown, "cannot send stream response: %v", err)
		}
	}
}

func handleProxyRequest(httpFilter HttpFilter, req *pb.ProcessingRequest) *pb.ProcessingResponse {
	switch v := req.Request.(type) {
	case *pb.ProcessingRequest_RequestHeaders:
		log.Debugf("Handling proxy request: %v", v)
		return httpFilter.OnRequestHeaders(req)

	case *pb.ProcessingRequest_RequestBody:
		return httpFilter.OnRequestBody(req)

	case *pb.ProcessingRequest_ResponseHeaders:
		log.Debugf("Handling proxy response: %v", v)
		return httpFilter.OnResponseHeaders(req)

	case *pb.ProcessingRequest_ResponseBody:
		return httpFilter.OnResponseBody(req)

	default:
		return CreateErrorProxyResponse(
			typev3.StatusCode_BadRequest,
			fmt.Sprintf("unexpected processing request type %T", v))
	}
}
