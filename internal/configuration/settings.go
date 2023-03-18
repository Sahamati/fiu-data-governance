package configuration

type Settings struct {
	// The Host of this sidecar.
	Host string `json:"host"`

	// The listening Port of this sidecar.
	Port int `json:"port"`

	// The trusted Local CCR containers.
	Local Local `json:"local"`

	// The trusted external Services.
	Services Services `json:"services"`

	// The HttpFilter type to use.
	Filter string `json:"filter"`
}

type Local struct {
	// The policy engine configuration.
	PolicyEngine PolicyEngine `json:"policy_engine"`
}

type Services struct {
}

type PolicyEngine struct {
	// The modules to load. Eg [example.rego] = `package ccr.policy .....`
	Modules map[string]string `json:"modules"`

	// The location from where to load the policies file if OPA is running embedded as a library.
	PoliciesDirectory string `json:"policies_directory"`

	// Base URL to contact the service with. Eg https://ghcr.io
	BundleServiceUrl string `json:"bundle_service_url"`

	// Resource path to use to download bundle from configured service. Eg: ghcr.io/${ORGANIZATION}/${REPOSITORY}[:${TAG}|@${DIGEST}]
	BundleResource string `json:"bundle_resource"`

	// The authentication scheme to use for private repositories.
	BundleServiceCredentialsScheme string `json:"bundle_service_credentials_scheme"`

	// username:password or PAT (personal access token) when downloading a private image.
	// Also used to workaround inability to pull public images https://github.com/open-policy-agent/opa/issues/5212
	BundleServiceCredentialsToken string `json:"bundle_service_credentials_token"`

	// Optional data object that gets loaded into the policy engine. Should be a valid JSON object.
	// This will get loaded in addition to any data files that get loaded from the bundle.
	Data map[string]interface{} `json:"data"`
}
