# Required
$ENV:RESOURCE_GROUP="kapilv-depa-inference-westeurope-rg"

# Required, eg "foo.azurecr.io"
$ENV:CONTAINER_REGISTRY="kapilvdepaacr.azurecr.io"

# Required, specify same value as CONTAINER_REGISTRY above if images are directly under it eg "foo.azurecr.io/ccr-init:latest" or
# say "foo.azurecr.io/some/path" if images are under paths like "foo.azurecr.io/some/path/ccr-init:latest", "foo.azurecr.io/some/path/ccr-sidecar:latest".
$ENV:IMAGE_PATH_PREFIX="kapilvdepaacr.azurecr.io"

# Optional, based on setup
$ENV:CONTAINER_REGISTRY_USERNAME="kapilvdepaacr"
$ENV:CONTAINER_REGISTRY_PASSWORD="g9sdl9RrhtBtKI2+ddwuHRmJqxMqptNI"
$ENV:USER_MI_ID=""
$ENV:CR_DNS_LABEL_NAME="cert-registry"
$ENV:BRE_DNS_LABEL_NAME="confbre"
$ENV:SA_DNS_LABEL_NAME="confsa"
$ENV:BUNDLE_SERVICE_URL=""
$ENV:BUNDLE_SERVICE_CREDENTIALS_SCHEME="Basic"
$ENV:BUNDLE_SERVICE_CREDENTIALS_TOKEN=""
