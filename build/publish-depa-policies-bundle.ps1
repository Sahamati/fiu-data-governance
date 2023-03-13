param(
  [Parameter( Mandatory = $true,
  HelpMessage = "The registry url.")]
  $registryUrl,

  [switch]$skipPush = $false
)

$ErrorActionPreference = "Stop"
$policyFilesPath = $PSScriptRoot + "/../samples/aa-flow-based-lending/policies"
$outputPath = [IO.Path]::GetTempPath() + "depa-policies"

function cleanup()
{
  if (test-path $outputPath\depa-policies.tar.gz) {
    Remove-Item -Force $outputPath\depa-policies.tar.gz
  }
}

cleanup

mkdir -p $outputPath

# Create the bundle.
# https://www.openpolicyagent.org/docs/latest/management-bundles/#building-and-publishing-policy-containers
$uid = id -u ${env:USER}
$gid = id -g ${env:USER}
docker run --rm `
  -u ${uid}:${gid} `
  -v ${policyFilesPath}:/workspace `
  -v ${outputPath}:/output `
  -w /workspace `
  openpolicyagent/opa build . --bundle -o /output/depa-policies.tar.gz

if (!$skipPush) {
    # Push the bundle to the registry. Need to Set-Location as need to use "./depa-policies.tar.gz"
    # as the path in the orash push command. If giving a path like /some/dir/depa-policies.tar.gz
    # then oras pull fails with "Error: failed to resolve path for writing: path traversal disallowed"
    Push-Location
    Set-Location $outputPath
    oras push $registryUrl/depa-policies:latest `
    --config $policyFilesPath/config.json:application/vnd.oci.image.config.v1+json `
    ./depa-policies.tar.gz:application/vnd.oci.image.layer.v1.tar+gzip
    Pop-Location
}

cleanup
