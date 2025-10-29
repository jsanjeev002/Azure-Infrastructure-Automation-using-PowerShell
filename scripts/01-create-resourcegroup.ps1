<#
 .SYNOPSIS
 Creates or verifies an Azure Resource Group.

 .DESCRIPTION
  This script creates a resource group if it doesn't exist.
  It includes parameter validation, error handling, and logging.

#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$rgName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$location,

    [Parameter(Mandatory = $false)]
    [string]$logFile = ".\ResourceGroupCreation.log"
)

# Enable strict mode and stop on errors
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Log function
function Write-Log {
    param([string]$message)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $entry = "[$timestamp] $message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

try {
    Write-Log "Starting Resource Group creation process..."
    
    # Check if the resource group already exists
    $existingRG = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue

    if ($existingRG) {
        Write-Log "Resource group '$rgName' already exists in location '$($existingRG.Location)'."
    } else {
        # Create new resource group
        New-AzResourceGroup -Name $rgName -Location $location | Out-Null
        Write-Log "Resource group '$rgName' created successfully in '$location'."
    }

    Write-Log "Script completed successfully."
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
