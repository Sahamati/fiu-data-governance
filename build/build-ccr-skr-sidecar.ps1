param(
  [bool]$gitSync = $false,
  [int]$port = 8284
)

$env:DOCKER_BUILDKIT = 1
$ErrorActionPreference = "Stop"

if ($gitSync) {
  Push-Location "$PSScriptRoot/.."
  git submodule sync --recursive
  git submodule update --init --recursive
  Pop-Location
}

docker image build -t "ccr-skr-sidecar" `
  -f $PSScriptRoot/docker/Dockerfile.skr "$PSScriptRoot/.." `
  --build-arg PORT=$port
