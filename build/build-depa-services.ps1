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

$services = @{
  "account-aggregator" = @("0.0.0.0", "8000")
  "financial-information-user" = @("0.0.0.0", "8001")
  "business-rule-engine" = @("0.0.0.0", "8080")
  "statement-analysis" = @("0.0.0.0", "8080")
  "certificate-registry" = @("0.0.0.0", "8080")
}

foreach ($service in $services.Keys) {
  docker image build -t "$service-service" `
    -f $PSScriptRoot/docker/Dockerfile.service `
    "$PSScriptRoot/../samples/aa-flow-based-lending/src/$service" `
    --build-arg HOST=$($services[$service][0]) `
    --build-arg PORT=$($services[$service][1])
}
