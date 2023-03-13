# Important note: This script is meant to run from inside the container

CCR_SIDECAR_CONFIG_STRING=$(cat << EOF
{
  "host": "127.0.0.1",
  "port": 8281,
  "local": {
    "policy_engine": {
      "bundle_service_url": "",
      "bundle_resource": "",
      "bundle_service_credentials_scheme": "",
      "bundle_service_credentials_token": "",
      "data": {}
    }
  }
}
EOF
)

NO_POLICY_DATA="{}"
echo $CCR_SIDECAR_CONFIG_STRING | \
    jq --argjson data "${POLICY_DATA:-$NO_POLICY_DATA}" \
       --argjson port ${PORT:-8281} \
    '(.port) |= ($port) | 
     (.local.policy_engine.bundle_service_url) |= env.BUNDLE_SERVICE_URL | 
     (.local.policy_engine.bundle_resource) |= env.BUNDLE_RESOURCE_PATH | 
     (.local.policy_engine.bundle_service_credentials_scheme) |= env.BUNDLE_SERVICE_CREDENTIALS_SCHEME | 
     (.local.policy_engine.bundle_service_credentials_token) |= env.BUNDLE_SERVICE_CREDENTIALS_TOKEN | 
     (.local.policy_engine.data) |= $data' \
     > /tmp/config.json

exec ./ccr-sidecar -c /tmp/config.json
