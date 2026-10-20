param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("on", "off", "status")]
    [string]$Action
)
$ErrorActionPreference = "Stop"
$tfDir = Join-Path (Split-Path -Parent $PSScriptRoot) "terraform"
if ($Action -eq "status") {
    $api = & terraform "-chdir=$tfDir" output -raw api_url
    if ($LASTEXITCODE -ne 0) { throw "Cannot read Terraform output; complete Step 11 first." }
    try {
        $health = Invoke-RestMethod -Uri "$($api.Trim())/health" -TimeoutSec 15
        if ($health.status -ne "ok") { throw "Unexpected health response" }
        Write-Host "ONLINE (application responding; storage not checked)"
    } catch {
        Write-Host "OFFLINE / UNREACHABLE: $($_.Exception.Message)"
        exit 1
    }
    exit 0
}
# Persist desired state so a later ordinary apply does not accidentally undo it.
$enabled = $Action -eq "on"
$settings = @{ demo_enabled = $enabled } | ConvertTo-Json
$path = Join-Path $tfDir "zz-demo.auto.tfvars.json"
[System.IO.File]::WriteAllText($path, $settings, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Desired state saved: demo_enabled=$enabled. Review the full apply plan."
& terraform "-chdir=$tfDir" apply
if ($LASTEXITCODE -ne 0) {
    throw "Apply failed/cancelled. Desired setting remains saved; actual AWS state may differ. Rerun after resolving the issue."
}
Write-Host "Apply complete. Run this script with status to check reachability."