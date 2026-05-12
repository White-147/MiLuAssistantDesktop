# Build a relocatable python-env using Python embeddable package + pip.
# No conda required. Run from the MiLuAssistantDesktop repo root:
#   powershell -ExecutionPolicy Bypass -File scripts\build-python-env.ps1
#
# This downloads the Python 3.11 embeddable package, installs pip,
# then pip-installs MiLuAssistantWeb and all its dependencies.

$ErrorActionPreference = "Stop"

$ProjectRoot = (Get-Item $PSScriptRoot).Parent.FullName
$CandidateRoots = @(
    "$ProjectRoot\..\MiLuAssistantWeb"
)
$MiLuRoot = $CandidateRoots | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $MiLuRoot) {
  throw "MiLuAssistantWeb source not found. Expected one of: $($CandidateRoots -join ', ')"
}
$MiLuRoot = (Get-Item $MiLuRoot).FullName
$PythonEnv   = Join-Path $ProjectRoot "python-env"
$BuildDir    = Join-Path $ProjectRoot "build"
$PY_VERSION  = "3.11.9"

Write-Host "=========================================="
Write-Host " MiLuAssistantDesktop - Build Python Environment"
Write-Host " (embeddable Python, no conda needed)"
Write-Host "=========================================="
Write-Host "MiLuAssistantWeb source : $MiLuRoot"
Write-Host "Target env   : $PythonEnv"
Write-Host "Python       : $PY_VERSION"
Write-Host ""

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

# ── Step 1: Download Python embeddable package ──
$PyMajorMinor = ($PY_VERSION -split '\.')[0..1] -join ''
$ZipName      = "python-$PY_VERSION-embed-amd64.zip"
$ZipPath      = Join-Path $BuildDir $ZipName
$PyUrl        = "https://www.python.org/ftp/python/$PY_VERSION/$ZipName"

if (-not (Test-Path $ZipPath)) {
  Write-Host "[build] Downloading $ZipName ..."
  Invoke-WebRequest -Uri $PyUrl -OutFile $ZipPath -UseBasicParsing
  Write-Host "[build] Downloaded to $ZipPath"
} else {
  Write-Host "[build] Using cached $ZipName"
}

# ── Step 2: Extract to python-env ──
if (Test-Path $PythonEnv) {
  Write-Host "[build] Removing old python-env..."
  Remove-Item -Recurse -Force $PythonEnv
}
Write-Host "[build] Extracting..."
Expand-Archive -Path $ZipPath -DestinationPath $PythonEnv -Force

$PyExe = Join-Path $PythonEnv "python.exe"
if (-not (Test-Path $PyExe)) {
  throw "python.exe not found after extraction"
}
Write-Host "[build] python.exe ready"

# ── Step 3: Enable import site + Lib/site-packages ──
$PthFile = Join-Path $PythonEnv "python${PyMajorMinor}._pth"
if (Test-Path $PthFile) {
  Write-Host "[build] Patching $PthFile to enable site-packages..."
  $content = Get-Content $PthFile -Raw
  $content = $content -replace '#\s*import site', 'import site'
  if ($content -notmatch 'Lib\\site-packages') {
    $content += "`nLib\site-packages`n"
  }
  Set-Content -Path $PthFile -Value $content -NoNewline
}

$SitePackages = Join-Path $PythonEnv "Lib\site-packages"
New-Item -ItemType Directory -Force -Path $SitePackages | Out-Null

# ── Step 4: Install pip ──
$GetPip = Join-Path $BuildDir "get-pip.py"
if (-not (Test-Path $GetPip)) {
  Write-Host "[build] Downloading get-pip.py..."
  Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile $GetPip -UseBasicParsing
}

Write-Host "[build] Installing pip..."
& $PyExe $GetPip --no-warn-script-location
if ($LASTEXITCODE -ne 0) { throw "get-pip.py failed" }

# Verify pip
& $PyExe -m pip --version
Write-Host "[build] pip installed"

# ── Step 5: Install MiLu ──
Write-Host "[build] Installing MiLu from source (editable mode skipped, using direct install)..."

# Try to find a wheel first
$Wheels = Get-ChildItem -Path (Join-Path $MiLuRoot "dist\milu-*.whl") -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending

if ($Wheels -and $Wheels.Count -gt 0) {
  $WheelPath = $Wheels[0].FullName
  Write-Host "[build] Installing from wheel: $WheelPath"
  & $PyExe -m pip install $WheelPath --no-warn-script-location
} else {
  Write-Host "[build] No wheel found, installing from source directory..."
  & $PyExe -m pip install $MiLuRoot --no-warn-script-location
}
if ($LASTEXITCODE -ne 0) { throw "MiLu installation failed" }

# ── Step 6: Verify installation ──
Write-Host "[build] Verifying MiLu installation..."
& $PyExe -c "from milu.__version__ import __version__; print(f'MiLu {__version__} installed successfully')"
if ($LASTEXITCODE -ne 0) { throw "MiLu verification failed" }

& $PyExe -c "import uvicorn; print(f'uvicorn {uvicorn.__version__}')"

# ── Step 7: Pre-compile in-place bytecode (-b flag) ──
Write-Host "[build] Compiling .py -> in-place .pyc ..."
& $PyExe -m compileall -b -q -j 0 $PythonEnv 2>$null
Write-Host "[build] In-place .pyc compilation done"

# ── Step 8: Strip python-env for minimal size & fastest NSIS install ──
Write-Host "[build] Stripping python-env for production..."

$beforeFiles = (Get-ChildItem $PythonEnv -Recurse -File -ErrorAction SilentlyContinue).Count
$beforeSize  = (Get-ChildItem $PythonEnv -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum

# 8a. Remove .py source files (in-place .pyc already exists)
Write-Host "  [8a] Removing .py source files..."
Get-ChildItem $SitePackages -Recurse -Filter "*.py" -File -ErrorAction SilentlyContinue |
  Where-Object {
    $pyc = $_.FullName -replace '\.py$', '.pyc'
    Test-Path $pyc
  } | Remove-Item -Force -ErrorAction SilentlyContinue

# 8b. Remove all __pycache__ directories (in-place .pyc used instead)
Write-Host "  [8b] Removing __pycache__ directories..."
Get-ChildItem $PythonEnv -Directory -Recurse -Filter "__pycache__" -ErrorAction SilentlyContinue |
  Sort-Object { $_.FullName.Length } -Descending |
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# 8c. Remove test/tests/testing directories
Write-Host "  [8c] Removing test directories..."
Get-ChildItem $SitePackages -Directory -Recurse -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -in @("tests", "test", "testing") } |
  Sort-Object { $_.FullName.Length } -Descending |
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# 8d. Remove unnecessary packages and dangling .pth files
Write-Host "  [8d] Removing unnecessary packages (pip, setuptools, pythonwin, _distutils_hack)..."
$pkgsToRemove = @("pip", "setuptools", "pythonwin", "_distutils_hack", "pkg_resources")
foreach ($pkg in $pkgsToRemove) {
  $pkgDir = Join-Path $SitePackages $pkg
  if (Test-Path $pkgDir) { Remove-Item $pkgDir -Recurse -Force -ErrorAction SilentlyContinue }
}
Get-ChildItem $SitePackages -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match "^(pip|setuptools|_distutils_hack)-.*\.dist-info$" } |
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $SitePackages "distutils-precedence.pth") -Force -ErrorAction SilentlyContinue

# 8e. Remove .pyi type stubs (not needed at runtime)
Write-Host "  [8e] Removing .pyi type stubs..."
Get-ChildItem $SitePackages -Recurse -Filter "*.pyi" -File -ErrorAction SilentlyContinue |
  Remove-Item -Force -ErrorAction SilentlyContinue

# 8f. Slim down dist-info (keep METADATA, top_level.txt, entry_points.txt)
Write-Host "  [8f] Slimming dist-info directories..."
Get-ChildItem $SitePackages -Directory -Filter "*.dist-info" -ErrorAction SilentlyContinue | ForEach-Object {
  Get-ChildItem $_.FullName -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notin @("METADATA", "top_level.txt", "entry_points.txt", "INSTALLER", "WHEEL") } |
    Remove-Item -Force -ErrorAction SilentlyContinue
}

# 8g. Remove docs/examples/locale directories inside packages
Write-Host "  [8g] Removing docs, examples, locale..."
Get-ChildItem $SitePackages -Directory -Recurse -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -in @("docs", "doc", "examples", "example", "locale") } |
  Sort-Object { $_.FullName.Length } -Descending |
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# 8h. Clean pip cache
Write-Host "  [8h] Cleaning pip cache..."
& $PyExe -m pip cache purge 2>$null

$afterFiles = (Get-ChildItem $PythonEnv -Recurse -File -ErrorAction SilentlyContinue).Count
$afterSize  = (Get-ChildItem $PythonEnv -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
$savedMB    = [math]::Round(($beforeSize - $afterSize) / 1MB, 1)
$savedFiles = $beforeFiles - $afterFiles

Write-Host ""
Write-Host "  Stripped: $savedFiles files, $savedMB MB saved"

# Report final size
$size = $afterSize / 1MB
Write-Host ""
Write-Host "=========================================="
Write-Host " python-env ready! Size: $([math]::Round($size, 1)) MB"
Write-Host " Files: $afterFiles"
Write-Host " You can now run: npm run dist"
Write-Host "=========================================="
