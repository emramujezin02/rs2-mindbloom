param(
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "MindBloom Docker image build"
Write-Host "========================================"
Write-Host ""

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker command was not found."
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git command was not found."
}

if ($Version -notmatch '^\d+\.\d+\.\d+([\-+][0-9A-Za-z\.-]+)?$') {
    throw "Version '$Version' is not a valid semantic version."
}

$GitCommit = (
    git rev-parse --short HEAD
).Trim()

if ([string]::IsNullOrWhiteSpace($GitCommit)) {
    throw "Git commit hash could not be determined."
}

$ApiImage = "mindbloom-api"
$WorkerImage = "mindbloom-worker"

Write-Host "Semantic version: $Version"
Write-Host "Git commit:       $GitCommit"
Write-Host ""

Write-Host "Building API image..."

docker build `
    --file "backend/src/MindBloom.API/Dockerfile" `
    --tag "${ApiImage}:${Version}" `
    --tag "${ApiImage}:${GitCommit}" `
    --tag "${ApiImage}:latest" `
    .

if ($LASTEXITCODE -ne 0) {
    throw "MindBloom API Docker image build failed."
}

Write-Host ""
Write-Host "Building Worker image..."

docker build `
    --file "backend/src/MindBloom.NotificationsWorker/Dockerfile" `
    --tag "${WorkerImage}:${Version}" `
    --tag "${WorkerImage}:${GitCommit}" `
    --tag "${WorkerImage}:latest" `
    .

if ($LASTEXITCODE -ne 0) {
    throw "MindBloom Worker Docker image build failed."
}

Write-Host ""
Write-Host "========================================"
Write-Host "Docker images built successfully"
Write-Host "========================================"

Write-Host ""
Write-Host "API:"
Write-Host "  ${ApiImage}:${Version}"
Write-Host "  ${ApiImage}:${GitCommit}"
Write-Host "  ${ApiImage}:latest"

Write-Host ""
Write-Host "Worker:"
Write-Host "  ${WorkerImage}:${Version}"
Write-Host "  ${WorkerImage}:${GitCommit}"
Write-Host "  ${WorkerImage}:latest"

Write-Host ""
Write-Host "To run Compose with this semantic version:"
Write-Host ""
Write-Host "  `$env:IMAGE_VERSION='$Version'"
Write-Host "  docker compose up"
