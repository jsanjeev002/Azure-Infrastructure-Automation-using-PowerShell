<#
.SYNOPSIS
    Creates or verifies a Virtual Network and Subnet in Azure.

.DESCRIPTION
    This script checks for an existing VNet and subnet before creating new ones.
    Includes parameter validation, error handling, idempotency, and logging.
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$rgName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$vnetName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$subnetName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$location,

    [Parameter(Mandatory = $false)]
    [string]$vnetAddressPrefix = "10.0.0.0/16",

    [Parameter(Mandatory = $false)]
    [string]$subnetAddressPrefix = "10.0.1.0/24",

    [Parameter(Mandatory = $false)]
    [string]$logFile = ".\NetworkCreation.log"
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
    Write-Log "Starting Virtual Network creation process..."

    # Validate Resource Group exists
    $rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
    if (-not $rg) {
        throw "Resource group '$rgName' does not exist. Please create it first."
    }

    # Check if VNet exists
    $existingVnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName -ErrorAction SilentlyContinue

    if ($existingVnet) {
        Write-Log "VNet '$vnetName' already exists in '$($existingVnet.Location)'."
    }
    else {
        Write-Log "Creating new VNet '$vnetName'..."
        $vnet = New-AzVirtualNetwork -ResourceGroupName $rgName -Location $location `
            -Name $vnetName -AddressPrefix $vnetAddressPrefix
        Write-Log "VNet '$vnetName' created successfully."
    }

    # Re-fetch the latest VNet object
    $vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName

    # Check if subnet exists
    $existingSubnet = $vnet.Subnets | Where-Object { $_.Name -eq $subnetName }

    if ($existingSubnet) {
        Write-Log "Subnet '$subnetName' already exists in VNet '$vnetName'."
    }
    else {
        Write-Log "Adding subnet '$subnetName'..."
        Add-AzVirtualNetworkSubnetConfig -Name $subnetName `
            -AddressPrefix $subnetAddressPrefix -VirtualNetwork $vnet | Out-Null

        $vnet | Set-AzVirtualNetwork | Out-Null
        Write-Log "Subnet '$subnetName' created successfully."
    }

    Write-Log "Network creation script completed successfully."
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
