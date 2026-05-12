# Quick dev start: create a symlink/junction to the system Python environment
# so you can run `npm start` without doing a full conda-pack.
#
# This script creates a python-env/ folder that points to your system Python,
# making `npm start` work during development.

$ErrorActionPreference = "Stop"

$ProjectRoot = (Get-Item $PSScriptRoot).Parent.FullName
$PythonEnv   = Join-Path $ProjectRoot "python-env"

Write-Host "=========================================="
Write-Host " MiLuAssistantDesktop - Dev Setup"
Write-Host "=========================================="

# Find the Python that has milu installed
$pythonExe = (Get-Command python -ErrorAction Stop).Source
Write-Host "System Python: $pythonExe"

# Verify milu is installed
& $pythonExe -c "from milu.__version__ import __version__; print(f'milu {__version__} found')"
if ($LASTEXITCODE -ne 0) {
  throw "milu not found in Python environment. Please install it first: pip install -e D:\code\MiLuAssistantWeb"
}

# Create python-env directory with a marker file
if (-not (Test-Path $PythonEnv)) {
  New-Item -ItemType Directory -Path $PythonEnv -Force | Out-Null
}

# Create a python.exe wrapper script that delegates to system Python
$PythonEnvRoot = Split-Path $pythonExe
Write-Host "Python env root: $PythonEnvRoot"

# For dev mode, create a .dev-mode marker so main.js knows to use system Python
$devMarker = Join-Path $ProjectRoot ".dev-mode"
@"
# Dev mode marker - main.js will use system Python instead of bundled python-env
PYTHON_EXE=$pythonExe
PYTHON_ROOT=$PythonEnvRoot
"@ | Set-Content -Path $devMarker -Encoding UTF8

Write-Host ""
Write-Host "Dev mode configured. Run: npm start"
Write-Host ""
