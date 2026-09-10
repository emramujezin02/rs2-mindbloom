param(
    [switch] $StartInfrastructure
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")

Write-Host "MindBloom lightweight development check"
Write-Host ""

if ($StartInfrastructure) {
    Write-Host "Starting SQL Server and RabbitMQ containers only..."
    Push-Location $repoRoot
    try {
        docker compose up -d sql-server rabbitmq
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host "Infrastructure: run with -StartInfrastructure to start SQL Server and RabbitMQ only."
}

Write-Host ""
Write-Host "Backend: start MindBloom.API in Visual Studio using the http profile."
Write-Host "Mobile:  run .\scripts\run-mobile.ps1 from MindBloom.Frontend."
Write-Host ""
Write-Host "This lightweight path does not start the Docker API or notifications worker."
