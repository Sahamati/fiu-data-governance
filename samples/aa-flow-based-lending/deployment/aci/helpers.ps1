
# https://stackoverflow.com/questions/73067603/pass-a-json-string-without-using-backslashes
function NeedsExtraEscaping {
    if ([System.Version]$PSVersionTable.PSVersion.ToString() -lt [System.Version]"7.3") {
        return $true
    }
    return $false
}
