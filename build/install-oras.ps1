if ($IsWindows) {
    curl.exe -sLO  https://github.com/oras-project/oras/releases/download/v0.15.1/oras_0.15.1_windows_amd64.zip
    tar.exe -xvzf oras_0.15.1_windows_amd64.zip
    mkdir -p %USERPROFILE%\bin\
    copy oras.exe %USERPROFILE%\bin\
    set PATH=%USERPROFILE%\bin\;%PATH%
}
else {
    curl -LO https://github.com/oras-project/oras/releases/download/v0.15.1/oras_0.15.1_linux_amd64.tar.gz
    mkdir -p oras-install/
    tar -zxf oras_0.15.1_*.tar.gz -C oras-install/
    mv oras-install/oras /usr/local/bin/
    rm -rf oras_0.15.1_*.tar.gz oras-install/
}