# Installs a prebuilt AutoTest CLI binary from the public dist repository.
#
# Usage:
#   irm https://raw.githubusercontent.com/DF-Packages/cn.dfdfdf.autotest-cli-dist/master/scripts/install.ps1 | iex

$ErrorActionPreference = 'Stop'

$BinName = 'autotest'
$Repo = if ($env:AUTOTEST_CLI_GITHUB_REPO) { $env:AUTOTEST_CLI_GITHUB_REPO } else { 'DF-Packages/cn.dfdfdf.autotest-cli-dist' }
$InstallDir = if ($env:AUTOTEST_CLI_INSTALL_DIR) { $env:AUTOTEST_CLI_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'dfdfdf\bin' }
$MetaDir = if ($env:AUTOTEST_CLI_META_DIR) { $env:AUTOTEST_CLI_META_DIR } else { Join-Path $env:USERPROFILE '.dfdfdf\autotest-cli' }
$Target = 'x86_64-pc-windows-msvc'
$Asset = "$BinName-$Target.zip"

if ($env:AUTOTEST_CLI_VERSION) {
  $Tag = $env:AUTOTEST_CLI_VERSION
  if (-not $Tag.StartsWith('v')) { $Tag = "v$Tag" }
  $ApiUrl = "https://api.github.com/repos/$Repo/releases/tags/$Tag"
} else {
  $ApiUrl = "https://api.github.com/repos/$Repo/releases/latest"
}

Write-Host "==> Fetching release info: $ApiUrl"
$Headers = @{
  'User-Agent' = "$BinName-installer"
  Accept = 'application/vnd.github+json'
}
$Release = Invoke-RestMethod -Headers $Headers -Uri $ApiUrl
$Tag = $Release.tag_name
if (-not $Tag) { throw 'GitHub release response does not contain tag_name' }
$Version = $Tag.TrimStart('v')
$BaseUrl = "https://github.com/$Repo/releases/download/$Tag"

$Tmp = New-Item -ItemType Directory -Path ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [guid]::NewGuid().ToString()))
try {
  $ZipPath = Join-Path $Tmp.FullName $Asset
  $SumsPath = Join-Path $Tmp.FullName 'SHA256SUMS'

  Write-Host "==> Downloading $Asset ($Tag)"
  Invoke-WebRequest -Uri "$BaseUrl/$Asset" -OutFile $ZipPath
  Invoke-WebRequest -Uri "$BaseUrl/SHA256SUMS" -OutFile $SumsPath

  Write-Host '==> Verifying checksum'
  $Pattern = "\s$([regex]::Escape($Asset))\s*$"
  $Expected = Get-Content $SumsPath |
    Where-Object { $_ -match $Pattern } |
    ForEach-Object { ($_ -split '\s+')[0] } |
    Select-Object -First 1
  if (-not $Expected) { throw "no checksum entry for $Asset" }

  $Actual = (Get-FileHash -Algorithm SHA256 -Path $ZipPath).Hash.ToLowerInvariant()
  if ($Actual -ne $Expected.ToLowerInvariant()) {
    throw "checksum mismatch for $Asset (expected $Expected, got $Actual)"
  }

  Expand-Archive -LiteralPath $ZipPath -DestinationPath $Tmp.FullName -Force
  $SourceBinary = Join-Path $Tmp.FullName "$BinName.exe"
  if (-not (Test-Path -LiteralPath $SourceBinary)) {
    throw "archive does not contain $BinName.exe"
  }

  New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
  New-Item -ItemType Directory -Force -Path $MetaDir | Out-Null
  $Destination = Join-Path $InstallDir "$BinName.exe"
  $StagedDestination = "$Destination.tmp.$PID"
  Copy-Item -LiteralPath $SourceBinary -Destination $StagedDestination -Force
  Move-Item -LiteralPath $StagedDestination -Destination $Destination -Force

  $Metadata = @{
    version = $Version
    binary = $Destination
    install_dir = $InstallDir
    github_repo = $Repo
    install_method = 'remote'
    target = $Target
    installed_at = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  } | ConvertTo-Json
  Set-Content -LiteralPath (Join-Path $MetaDir 'install.json') -Value $Metadata -Encoding UTF8

  Write-Host "Installed $BinName $Version -> $Destination"
  & $Destination --version
  Write-Host "Add to PATH if needed: $InstallDir"
} finally {
  Remove-Item -Recurse -Force $Tmp.FullName -ErrorAction SilentlyContinue
}
