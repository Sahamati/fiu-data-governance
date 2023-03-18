package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net"
	"os"

	log "github.com/sirupsen/logrus"

	"google.golang.org/grpc"

	pb "github.com/envoyproxy/go-control-plane/envoy/service/ext_proc/v3"
	configuration "github.com/microsoft/confidential-depa/internal/configuration"
	"github.com/microsoft/confidential-depa/internal/filter"
	"github.com/microsoft/confidential-depa/internal/filter/opa"
)

var (
	configFile = flag.String("c", "", "config file")
)

func main() {
	flag.Parse()
	log.SetFormatter(&log.TextFormatter{
		DisableQuote: true,
	})

	jsonFile, err := os.Open(*configFile)
	if err != nil {
		log.Fatalf("failed to open config file: %v", err)
	}

	defer jsonFile.Close()
	byteValue, err := io.ReadAll(jsonFile)
	if err != nil {
		log.Fatalf("failed to read config file: %v", err)
	}

	config := configuration.Settings{}
	err = json.Unmarshal(byteValue, &config)
	if err != nil {
		log.Fatalf("failed to unmarshal config file: %v", err)
	}

	if config.Host == "" {
		config.Host = "127.0.0.1"
	}
	if config.Port == 0 {
		config.Port = 8281
	}

	token := config.Local.PolicyEngine.BundleServiceCredentialsToken
	config.Local.PolicyEngine.BundleServiceCredentialsToken = "****"
	log.Infof("Configuration options: %+v", config)
	config.Local.PolicyEngine.BundleServiceCredentialsToken = token

	address := fmt.Sprintf("%s:%d", config.Host, config.Port)
	lis, err := net.Listen("tcp", address)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	var ff filter.HttpFilterFactory
	switch config.Filter {
	case "opa":
		fallthrough
	default:
		ff, err = opa.NewHttpFilterFactory(config.Local.PolicyEngine)
		if err != nil {
			log.Fatalf("failed to create filter factory: %v", err)
		}
	}

	grpcServer := grpc.NewServer()
	pb.RegisterExternalProcessorServer(grpcServer, filter.NewExternalProcessorServer(ff))

	log.Infof("Listening on %s", address)
	err = grpcServer.Serve(lis)
	if err != nil {
		log.Fatalf("failed start gRPC server: %v", err)
	}
}
