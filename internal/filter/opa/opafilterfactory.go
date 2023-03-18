package opa

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/microsoft/confidential-depa/internal/configuration"
	"github.com/microsoft/confidential-depa/internal/filter"
	"github.com/open-policy-agent/opa/bundle"
	"github.com/open-policy-agent/opa/download"
	"github.com/open-policy-agent/opa/keys"
	"github.com/open-policy-agent/opa/plugins"
	"github.com/open-policy-agent/opa/plugins/rest"
	"github.com/open-policy-agent/opa/rego"
	"github.com/open-policy-agent/opa/storage"
	"github.com/open-policy-agent/opa/storage/inmem"
	log "github.com/sirupsen/logrus"
)

type rule string

const (
	rule_OnRequestHeaders  rule = "on_request_headers"
	rule_OnRequestBody     rule = "on_request_body"
	rule_OnResponseHeaders rule = "on_response_headers"
	rule_OnResponseBody    rule = "on_response_body"
)

var rules = []rule{
	rule_OnRequestHeaders,
	rule_OnRequestBody,
	rule_OnResponseHeaders,
	rule_OnResponseBody,
}

type opaFilterFactory struct {
	config        configuration.PolicyEngine
	policyQueries map[rule]rego.PreparedEvalQuery
	teeType       string
}

func (self *opaFilterFactory) CreateFilter() filter.HttpFilter {
	return &opaFilter{
		policyQueries: self.policyQueries,
		teeType:       self.teeType,
	}
}

func NewHttpFilterFactory(config configuration.PolicyEngine) (filter.HttpFilterFactory, error) {
	policySet := make(map[string]string)
	var bundle *bundle.Bundle = nil
	if config.PoliciesDirectory != "" {
		files, err := os.ReadDir(config.PoliciesDirectory)
		if err != nil {
			log.Errorf("failed to ReadDir %s: %s", config.PoliciesDirectory, err)
			return nil, err
		}

		for _, file := range files {
			if !file.IsDir() && filepath.Ext(file.Name()) == ".rego" {
				filePath := filepath.Join(config.PoliciesDirectory, file.Name())
				contents, err := os.ReadFile(filePath)
				if err != nil {
					log.Errorf("failed to ReadFile %q: %s", filePath, err)
					return nil, err
				}

				policySet[file.Name()] = string(contents)
			}
		}
	} else if config.BundleResource != "" {
		t := plugins.TriggerManual
		dlConfig := download.Config{
			Trigger: &t,
		}

		err := dlConfig.ValidateAndInjectDefaults()
		if err != nil {
			log.Errorf("failed to create a valid download config: %s", err)
			return nil, err
		}

		bundleServiceUrl := config.BundleServiceUrl
		if bundleServiceUrl == "" {
			bundleServiceUrl = "https://" + strings.Split(config.BundleResource, "/")[0]
		}

		var restConfig []byte
		if config.BundleServiceCredentialsToken != "" {
			scheme := config.BundleServiceCredentialsScheme
			if scheme == "" {
				scheme = "Bearer"
			}

			restConfig = []byte(fmt.Sprintf(`{
				"url": %q,
				"credentials": {
					"bearer": {
						"scheme": %q,
						"token": %q
					}
				}
			}`,
				bundleServiceUrl,
				scheme,
				config.BundleServiceCredentialsToken))
		} else {
			restConfig = []byte(fmt.Sprintf(`{
				"url": %q
			}`, bundleServiceUrl))
		}

		client, err := rest.New(restConfig, map[string]*keys.Config{})
		if err != nil {
			log.Errorf("failed to create rest client: %s", err)
			return nil, err
		}

		var update *download.Update
		d := download.NewOCI(dlConfig, client, config.BundleResource, "/tmp/opa/oci/").
			WithCallback(func(_ context.Context, u download.Update) {
				update = &u
			})

		log.Infof("Triggering policy bundle download from oci registry.")
		ctx := context.Background()
		err = d.Trigger(ctx)
		if err != nil {
			log.Errorf("failed to trigger bundle download: %s", err)
			return nil, err
		}

		if update.Error != nil {
			log.Errorf("failed to download bundle: %s", update.Error)
			return nil, update.Error
		}

		if update.Bundle == nil || len(update.Bundle.Modules) == 0 {
			log.Errorf("expected bundle with at least one module but got none")
			return nil, fmt.Errorf("expected bundle with at least one module but got none")
		}

		bundle = update.Bundle
		log.Infof("Bundle downloaded successfully.")
	} else if config.Modules != nil {
		policySet = config.Modules
	} else {
		return nil, fmt.Errorf("Need to specify a bundle_resource.")
	}

	factory := &opaFilterFactory{
		config:        config,
		policyQueries: make(map[rule]rego.PreparedEvalQuery),
	}

	// Check if sev device exists on the platform; if not then ccr is being hosted on
	// non-confidential compute.
	if _, err := os.Stat("/dev/sev"); os.IsNotExist(err) {
		factory.teeType = "none"
	} else {
		factory.teeType = "sevsnpvm"
	}

	// Load the data in the policy if it was specified.
	var jsonConfig map[string]interface{} = make(map[string]interface{})
	if config.Data != nil {
		jsonConfig = config.Data
	}

	store := inmem.NewFromObject(jsonConfig)
	txn, err := store.NewTransaction(context.Background(), storage.WriteParams)
	if err != nil {
		log.Errorf("failed to create new transaction: %s", err)
		return nil, err
	}

	for _, r := range rules {
		var err error
		query := fmt.Sprintf("data.ccr.policy.%s", r)
		factory.policyQueries[r], err = preparePolicyEval(query, policySet, bundle, store, txn)
		if err != nil {
			log.Errorf("failed to prepare %s query: %s", r, err)
			return nil, err
		}
	}

	err = store.Commit(context.Background(), txn)
	if err != nil {
		log.Errorf("failed to commit store transaction: %s", err)
		return nil, err
	}

	return factory, nil
}

func preparePolicyEval(
	query string,
	policySet map[string]string,
	bundle *bundle.Bundle,
	store storage.Store,
	txn storage.Transaction) (rego.PreparedEvalQuery, error) {
	modules := []func(*rego.Rego){}
	for filename, policy := range policySet {
		modules = append(modules, rego.Module(filename, policy))
	}

	ctx := context.TODO()
	opts := []func(*rego.Rego){rego.Query(query)}
	opts = append(opts, modules...)
	opts = append(opts, rego.Store(store))
	opts = append(opts, rego.EnablePrintStatements(true))
	opts = append(opts, rego.Trace(true))
	opts = append(opts, rego.Transaction(txn))
	if bundle != nil {
		opts = append(opts, rego.ParsedBundle("bundle", bundle))
	}
	preparedQuery, err := rego.New(opts...).PrepareForEval(ctx)
	if err != nil {
		log.Errorf("failed to PrepareForEval %s: %s", query, err)
		return rego.PreparedEvalQuery{}, err
	}

	return preparedQuery, nil
}
