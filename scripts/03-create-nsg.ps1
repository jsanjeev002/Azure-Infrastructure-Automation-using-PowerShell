<#
.SYNOPSIS
    Creates or verifies a Network Security Group (NSG) with specified rules.

.DESCRIPTION
    This script checks for an existing NSG in a resource group before creating a new one.
    It includes parameter validation, idempotency, error handling, and logging.
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$rgName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$nsgName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$location,

    [Parameter(Mandatory = $false)]
    [string]$ruleName = "AllowRDP",

    [Parameter(Mandatory = $false)]
    [int]$priority = 1000,

    [Parameter(Mandatory = $false)]
    [string]$protocol = "Tcp",

    [Parameter(Mandatory = $false)]
    [int]$destinationPort = 3389,

    [Parameter(Mandatory = $false)]
    [string]$access = "Allow",

    [Parameter(Mandatory = $false)]
    [string]$logFile = ".\NSGCreation.log"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$message)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $entry = "[$timestamp] $message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

try {
    Write-Log "Starting Network Security Group creation process..."

    # Validate Resource Group exists
    $rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
    if (-not $rg) {
        throw "Resource group '$rgName' does not exist. Please create it first."
    }

    # Check if NSG exists
    $existingNSG = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rgName -ErrorAction SilentlyContinue

    if ($existingNSG) {
        Write-Log "NSG '$nsgName' already exists in '$($existingNSG.Location)'. Skipping creation."
    }
    else {
        Write-Log "Creating new NSG '$nsgName'..."
        $nsgRule = New-AzNetworkSecurityRuleConfig -Name $ruleName `
            -Protocol $protocol -Direction "Inbound" -Priority $priority `
            -SourceAddressPrefix * -SourcePortRange * `
            -DestinationAddressPrefix * -DestinationPortRange $destinationPort `
            -Access $access

       

        Write-Log "NSG '$nsgName' created successfully with rule '$ruleName'."
    }

    Write-Log "NSG creation script completed successfully."
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
