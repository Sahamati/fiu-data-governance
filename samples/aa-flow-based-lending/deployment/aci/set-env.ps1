# Required
$ENV:RESOURCE_GROUP=""

# Required, eg "foo.azurecr.io"
$ENV:CONTAINER_REGISTRY=""

# Required, specify same value as CONTAINER_REGISTRY above if images are directly under it eg "foo.azurecr.io/ccr-init:latest" or
# say "foo.azurecr.io/some/path" if images are under paths like "foo.azurecr.io/some/path/ccr-init:latest", "foo.azurecr.io/some/path/ccr-sidecar:latest".
$ENV:IMAGE_PATH_PREFIX=""

# Optional, based on setup
$ENV:CONTAINER_REGISTRY_USERNAME=""
$ENV:CONTAINER_REGISTRY_PASSWORD=""
$ENV:USER_MI_ID=""
$ENV:CR_DNS_LABEL_NAME=""
$ENV:BRE_DNS_LABEL_NAME=""
$ENV:SA_DNS_LABEL_NAME=""
$ENV:BUNDLE_SERVICE_URL=""
$ENV:BUNDLE_SERVICE_CREDENTIALS_SCHEME=""
$ENV:BUNDLE_SERVICE_CREDENTIALS_TOKEN=""
