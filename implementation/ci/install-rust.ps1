if ($IsWindows) {
  # Create external directory if it doesn't exist.
  $externalDir = "$PSScriptRoot/external"
  if (!(Test-Path -path $externalDir)) {
    New-Item -Path $externalDir -ItemType directory
  }

  # Download Rust, if it does not exist locally.
  $rustup = "rustup-init.exe"
  if (!(Test-Path -path "$externalDir/$rustup")) {
    Push-Location $externalDir
    $url = "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe"
    Invoke-WebRequest $url -OutFile "$externalDir/$rustup"
    Pop-Location
  }
}

if (!(Get-Command "rustup" -ErrorAction SilentlyContinue)) {
  # Install Rust.
  if ($IsWindows) {
    & "$externalDir/$rustup" -y
  } else {
    & curl https://sh.rustup.rs -sSf | sh -s -- -y
  }

  # Update path without restarting the shell.
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" `
    + [System.Environment]::GetEnvironmentVariable("Path","User")
}

# Update Rust.
rustup update stable
rustup default stable
