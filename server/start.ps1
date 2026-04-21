$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

if (-not (Test-Path ".env")) {
  if (Test-Path ".env.example") {
    Write-Host "No .env found. Copying from .env.example..."
    Copy-Item ".env.example" ".env"
  } else {
    Write-Error "Missing .env and .env.example in server folder."
  }
}

Write-Host "Installing server dependencies..."
dart pub get

Write-Host "Starting TicTacToe server..."
dart run bin/server.dart
