$envoyVersion = "1.20.0"
$validateVersion = "0.6.1"
$xdsVersion = "01bcc9b48dfec9ddf68b50b3e3bbee830da9c3ae"

$envoyUrl = "https://github.com/envoyproxy/envoy/archive/refs/tags/v$envoyVersion.zip"
$validateUrl = "https://github.com/envoyproxy/protoc-gen-validate/archive/refs/tags/v$validateVersion.zip"
$xdsUrl = "https://github.com/cncf/xds/archive/$xdsVersion.zip"

Push-Location $PSScriptRoot
Invoke-WebRequest $envoyUrl -OutFile $PSScriptRoot/envoy.zip
Invoke-WebRequest $validateUrl -OutFile $PSScriptRoot/validate.zip
Invoke-WebRequest $xdsUrl -OutFile $PSScriptRoot/xds.zip
Pop-Location

# Unzip the archives.
Expand-Archive -LiteralPath $PSScriptRoot/envoy.zip -DestinationPath $PSScriptRoot
Expand-Archive -LiteralPath $PSScriptRoot/validate.zip -DestinationPath $PSScriptRoot
Expand-Archive -LiteralPath $PSScriptRoot/xds.zip -DestinationPath $PSScriptRoot

# Copy protobuf files.
Copy-Item -Path $PSScriptRoot/envoy-$envoyVersion/api/envoy -Destination $PSScriptRoot -Recurse -Filter *.proto -Force
Copy-Item -Path $PSScriptRoot/protoc-gen-validate-$validateVersion/validate -Destination $PSScriptRoot -Recurse -Filter *.proto -Force
Copy-Item -Path $PSScriptRoot/xds-$xdsVersion/udpa -Destination $PSScriptRoot -Recurse -Filter *.proto -Force
Copy-Item -Path $PSScriptRoot/xds-$xdsVersion/xds -Destination $PSScriptRoot -Recurse -Filter *.proto -Force

# Cleanup.
Remove-Item -Path $PSScriptRoot/envoy-$envoyVersion -Recurse -Force
Remove-Item -Path $PSScriptRoot/protoc-gen-validate-$validateVersion -Recurse -Force
Remove-Item -Path $PSScriptRoot/xds-$xdsVersion -Recurse -Force
Remove-Item -Path $PSScriptRoot/envoy.zip -Force
Remove-Item -Path $PSScriptRoot/validate.zip -Force
Remove-Item -Path $PSScriptRoot/xds.zip -Force
