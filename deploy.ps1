<#
.SYNOPSIS
  Terraform wrapper for the Microsoft Sentinel POC (Windows / PowerShell).
  Functional twin of deploy.sh.

.DESCRIPTION
  Concept mirrors terraform-codebase/art-app-azure: flat tf-resources dir,
  non-secret vars in terraform.tfvars, secrets in sensitive.auto.tfvars.
  State is stored locally (tf-resources/terraform.tfstate, git-ignored).
  Single operator only - no remote backend / state locking.

.PARAMETER Action
  init | plan | apply | destroy | validate | fmt | refresh | show-plan-json

.PARAMETER Environment
  poc

.PARAMETER PlanTimestamp
  Required for apply / show-plan-json - the timestamp of the plan file to use.

.EXAMPLE
  .\deploy.ps1 init poc
  .\deploy.ps1 plan poc
  .\deploy.ps1 apply poc 20260907T120000Z
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory, Position = 0)]
  [ValidateSet('init', 'plan', 'apply', 'destroy', 'validate', 'fmt', 'refresh', 'show-plan-json')]
  [string]$Action,

  [Parameter(Mandatory, Position = 1)]
  [ValidateSet('poc')]
  [string]$Environment,

  [Parameter(Position = 2)]
  [string]$PlanTimestamp
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$DateStamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd')

function Require-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Get-TfVarValue([string]$FilePath, [string]$Key) {
  if (-not (Test-Path $FilePath)) { throw "Terraform vars file not found: $FilePath" }
  foreach ($line in Get-Content -LiteralPath $FilePath) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$') {
      if ($Matches[1] -eq $Key) {
        return $Matches[2].Trim().Trim('"')
      }
    }
  }
  return $null
}

# ── Paths ────────────────────────────────────────────────────────────────────
$RootPath        = $PSScriptRoot
$EnvPath         = Join-Path $RootPath "environments/$Environment"
$TfResourcesPath = Join-Path $EnvPath 'tf-resources'
$PlansPath       = Join-Path $EnvPath 'plans'
$OutputsPath     = Join-Path $EnvPath "outputs/$DateStamp"
$VarsFile        = Join-Path $TfResourcesPath 'terraform.tfvars'
$SensitiveVars   = Join-Path $TfResourcesPath 'sensitive.auto.tfvars'

if (-not (Test-Path $TfResourcesPath)) { throw "Not found: $TfResourcesPath" }
New-Item -ItemType Directory -Force -Path $PlansPath, $OutputsPath | Out-Null

if ($Action -in @('apply', 'show-plan-json') -and -not $PlanTimestamp) {
  throw "PlanTimestamp is required for '$Action'."
}

# ── Names ────────────────────────────────────────────────────────────────────
$Company = Get-TfVarValue $VarsFile 'company_name_short'
$Product = Get-TfVarValue $VarsFile 'product_name_short'
$StateKeyFileName = "$Environment-$Company-$Product.tfstate"

$PlanRef = if ($Action -eq 'plan') { $Timestamp } else { $PlanTimestamp }
$PlanFilePath   = Join-Path $PlansPath   "$Environment-$Company-$Product-$PlanRef.tfplan"
$OutputFilePath = Join-Path $OutputsPath "$Environment-$Company-$Product-$Action-$Timestamp.log"

function Invoke-Logged {
  param([string[]]$TfArgs)
  Write-Host "terraform $($TfArgs -join ' ')"
  & terraform @TfArgs 2>&1 | Tee-Object -FilePath $OutputFilePath -Append
  if ($LASTEXITCODE -ne 0) { throw "terraform exited with code $LASTEXITCODE" }
}

Require-Command terraform

Write-Host '----------------------------------------------------------------------'
Write-Host "Action=[$Action] Environment=[$Environment] State=[local: $StateKeyFileName]"
Write-Host '----------------------------------------------------------------------'

switch ($Action) {
  'init' {
    Invoke-Logged @("-chdir=$TfResourcesPath", 'init', '-upgrade=true', '-no-color')
  }
  'plan' {
    Invoke-Logged @(
      "-chdir=$TfResourcesPath", 'plan', '-no-color', '-refresh=true',
      "-var-file=$VarsFile", "-var-file=$SensitiveVars", "-out=$PlanFilePath"
    )
    Write-Host "`nPlan file: $PlanFilePath"
  }
  'apply' {
    if (-not (Test-Path $PlanFilePath)) { throw "Plan file not found: $PlanFilePath" }
    Invoke-Logged @("-chdir=$TfResourcesPath", 'apply', '-no-color', $PlanFilePath)
  }
  'destroy' {
    Invoke-Logged @(
      "-chdir=$TfResourcesPath", 'destroy', '-no-color', '-refresh=true',
      "-var-file=$VarsFile", "-var-file=$SensitiveVars"
    )
  }
  'validate' { & terraform -chdir="$TfResourcesPath" validate -no-color }
  'fmt' { & terraform -chdir="$TfResourcesPath" fmt -recursive -no-color }
  'refresh' {
    Invoke-Logged @(
      "-chdir=$TfResourcesPath", 'refresh', '-no-color',
      "-var-file=$VarsFile", "-var-file=$SensitiveVars"
    )
  }
  'show-plan-json' {
    if (-not (Test-Path $PlanFilePath)) { throw "Plan file not found: $PlanFilePath" }
    & terraform -chdir="$TfResourcesPath" show -json $PlanFilePath
  }
}

Write-Host "Finished. Log: $OutputFilePath"
