Add-Content -Path $PROFILE -Value "`n$(Get-Content -Raw .\uname.ps1)"

# Remember to run . $PROFILE afterwards