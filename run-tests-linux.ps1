<#
.SYNOPSIS
    Runs the Fluidra-pool test suite inside a Linux container.

.DESCRIPTION
    The suite cannot run from the Windows working tree, for two independent reasons:

      1. The repo ships custom_components/fluidra_pool/select/aux.py, and AUX is a
         reserved DOS device name, so Git cannot create that file here. Without it,
         9 test files fail at collection. See WINDOWS-CHECKOUT.md.
      2. Home Assistant imports fcntl, which is POSIX-only, so the harness will not
         even load on Windows.

    Cloning the repo inside a Linux container solves both at once: the clone happens
    on a filesystem that has no problem with aux.py, and pytest runs on Linux.

    Python 3.14 is not a whim: pytest-homeassistant-custom-component requires it,
    and it is what CI uses.

.PARAMETER Branch
    Branch to test. Defaults to the branch currently checked out.

.PARAMETER PytestArgs
    Extra arguments for pytest. Defaults to -q.

.EXAMPLE
    .\run-tests-linux.ps1

.EXAMPLE
    .\run-tests-linux.ps1 -Branch fix/number-setpoints-no-fake-defaults

.EXAMPLE
    .\run-tests-linux.ps1 -PytestArgs "tests/test_number.py -v"
#>
param(
    [string]$Branch,
    [string]$PytestArgs = "-q"
)

$ErrorActionPreference = "Stop"

$Repo = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $Branch) {
    $Branch = (& git -C $Repo rev-parse --abbrev-ref HEAD).Trim()
}

# Docker Desktop wants forward slashes; :ro keeps the container from touching the tree.
$Mount = ($Repo -replace '\\', '/') + ":/src:ro"

Write-Host "repo   : $Repo"
Write-Host "branch : $Branch"
Write-Host "pytest : $PytestArgs"
Write-Host ""

# The && live inside this string, so bash runs them in the container.
# PowerShell 5.1 never sees them, which is the whole point.
$Script = "git clone -q -b $Branch /src /work && cd /work && pip install -q -r requirements_test.txt && pytest $PytestArgs"

& docker run --rm -v $Mount python:3.14 bash -c $Script

exit $LASTEXITCODE
