# Runs the Luna Health FastAPI backend and restarts it if it ever crashes.
# Registered as a Scheduled Task (LunaHealthBackend) that fires at user logon.
Set-Location -Path $PSScriptRoot
$logFile = Join-Path $PSScriptRoot "backend.log"

while ($true) {
    "$(Get-Date -Format o)  starting uvicorn" | Out-File -FilePath $logFile -Append -Encoding utf8
    & python -m uvicorn main:app --host 0.0.0.0 --port 8000 *>> $logFile
    "$(Get-Date -Format o)  uvicorn exited (code $LASTEXITCODE), restarting in 5s" | Out-File -FilePath $logFile -Append -Encoding utf8
    Start-Sleep -Seconds 5
}
