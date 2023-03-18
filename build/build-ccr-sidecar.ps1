param(
  [bool]$gitSync = $false
)

$env:DOCKER_BUILDKIT = 1
$ErrorActionPreference = "Stop"

if ($gitSync) {
  Push-Location "$PSScriptRoot/.."
  git submodule sync --recursive
  git submodule update --init --recursive
  Pop-Location
}

docker image build -t "ccr-sidecar" `
  -f $PSScriptRoot/docker/Dockerfile.sidecar "$PSScriptRoot/.."
