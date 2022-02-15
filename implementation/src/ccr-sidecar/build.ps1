Push-Location $PSScriptRoot

cargo build --release --workspace

if (!(Test-Path -path $PSScriptRoot/dist)) {
  New-Item -ItemType directory -Path $PSScriptRoot/dist
}

$targetDir = "$PSScriptRoot/target/release"
Copy-Item $targetDir/ccr-sidecar.exe $PSScriptRoot/dist/

Pop-Location
