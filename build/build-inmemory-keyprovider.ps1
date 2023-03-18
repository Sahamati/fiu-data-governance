param(
  [bool]$gitSync = $false,
  [bool]$nowarnings = $false
)

$env:DOCKER_BUILDKIT = 1
$ErrorActionPreference = "Stop"

if ($gitSync) {
  Push-Location "$PSScriptRoot/.."
  git submodule sync --recursive
  git submodule update --init --recursive
  Pop-Location
}

docker image build -t "inmemory-keyprovider" `
-f $PSScriptRoot/docker/Dockerfile.inmemory-keyprovider "$PSScriptRoot/.."
