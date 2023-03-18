package opa

import (
	"encoding/json"
	"fmt"
	"net/http"

	typev3 "github.com/envoyproxy/go-control-plane/envoy/type/v3"
)

type evalResult struct {
	decision interface{}
}

func NewEvalResult(decision interface{}) evalResult {
	return evalResult{
		decision: decision,
	}
}

func (result *evalResult) IsAllowed() (bool, error) {
	switch decision := result.decision.(type) {
	case bool:
		return decision, nil
	case map[string]interface{}:
		var val interface{}
		var ok, allowed bool

		if val, ok = decision["allowed"]; !ok {
			return false, fmt.Errorf("unable to determine evaluation result due to missing \"allowed\" key")
		}

		if allowed, ok = val.(bool); !ok {
			return false, fmt.Errorf("type assertion error")
		}

		return allowed, nil
	}

	return false, result.invalidDecisionErr()
}

func (result *evalResult) IsImmediateResponse() (bool, error) {
	var ok bool
	var val interface{}
	var decision map[string]interface{}

	if decision, ok = result.decision.(map[string]interface{}); !ok {
		return false, nil
	}

	if val, ok = decision["immediate_response"]; !ok {
		return false, nil
	}

	switch immediate_response := val.(type) {
	case bool:
		return immediate_response, nil
	default:
		return false, fmt.Errorf("type assertion error for \"immediate_response\"")
	}
}

// GetResponseContext returns the context to maintain for the current request
func (result *evalResult) GetResponseContext() (interface{}, error) {
	var ok bool
	var val interface{}
	var decision map[string]interface{}

	if decision, ok = result.decision.(map[string]interface{}); !ok {
		return nil, nil
	}

	if val, ok = decision["context"]; !ok {
		return nil, nil
	}

	switch context := val.(type) {
	case string:
		return context, nil
	case map[string]interface{}:
		return context, nil
	default:
		return nil, fmt.Errorf("type assertion error for \"context\"")
	}
}

// GetResponseBody returns the http body to return if they are part of the decision
func (result *evalResult) GetResponseBody() (string, error) {
	var ok bool
	var val interface{}
	var decision map[string]interface{}

	if decision, ok = result.decision.(map[string]interface{}); !ok {
		return "", nil
	}

	if val, ok = decision["body"]; !ok {
		return "", nil
	}

	switch body := val.(type) {
	case string:
		return body, nil
	case map[string]interface{}:
		jsonBody, err := json.Marshal(body)
		if err != nil {
			return "", fmt.Errorf("error marshalling response body to JSON: %v", err)
		}

		return string(jsonBody), nil
	default:
		return "", fmt.Errorf("type assertion error for \"body\"")
	}
}

// GetResponseHTTPStatus returns the http status to return if they are part of the decision
func (result *evalResult) GetResponseHTTPStatus() (int, error) {
	var ok bool
	var val interface{}
	var statusCode json.Number

	status := http.StatusForbidden

	switch decision := result.decision.(type) {
	case bool:
		if decision {
			return http.StatusOK, fmt.Errorf("HTTP status code undefined for simple 'allow'")
		}

		return status, nil
	case map[string]interface{}:
		if val, ok = decision["http_status"]; !ok {
			return status, nil
		}

		if statusCode, ok = val.(json.Number); !ok {
			return status, fmt.Errorf("type assertion error")
		}

		httpStatusCode, err := statusCode.Int64()
		if err != nil {
			return status, fmt.Errorf("error converting JSON number to int: %v", err)
		}

		if http.StatusText(int(httpStatusCode)) == "" {
			return status, fmt.Errorf("Invalid HTTP status code %v", httpStatusCode)
		}

		return int(httpStatusCode), nil
	}

	return http.StatusForbidden, result.invalidDecisionErr()
}

// GetResponseEnvoyHTTPStatus returns the http status to return if they are part of the decision
func (result *evalResult) GetResponseEnvoyHTTPStatus() (typev3.StatusCode, error) {
	code := typev3.StatusCode_Forbidden
	httpStatusCode, err := result.GetResponseHTTPStatus()
	if err != nil {
		return code, err
	}

	//This check is partially redundant but might be more strict than http.StatusText()
	if _, ok := typev3.StatusCode_name[int32(httpStatusCode)]; !ok {
		return code, fmt.Errorf("Invalid HTTP status code %v", httpStatusCode)
	}

	code = typev3.StatusCode(int32(httpStatusCode))
	return code, nil
}

func (result *evalResult) invalidDecisionErr() error {
	return fmt.Errorf("illegal value for policy evaluation result: %T", result.decision)
}
