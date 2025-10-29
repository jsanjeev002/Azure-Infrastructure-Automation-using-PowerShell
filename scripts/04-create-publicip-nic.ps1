<#
.SYNOPSIS
    Creates a network interface (NIC) for an Azure VM with subnet, NSG, and public IP.

.DESCRIPTION
    This script creates a Public IP, Network Interface (NIC),
    and attaches it to an existing Virtual Network, Subnet, and NSG.
    Includes logging, validation, and idempotent (safe re-run) checks.
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$rgName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$location,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$vnetName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$subnetName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$nsgName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$publicIpName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$nicName,

    [Parameter(Mandatory = $false)]
    [string]$logFile = ".\NetworkInterfaceCreation.log"
)

# Strict mode and fail-fast behavior
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Logging function
function Write-Log {
    param([string]$message)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $entry = "[$timestamp] $message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

try {
    Write-Log "Starting NIC creation process..."

    # Fetch dependencies
    $vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName -ErrorAction Stop
    $subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet
    $nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rgName

    # --- Public IP Creation ---
    $publicIp = Get-AzPublicIpAddress -Name $publicIpName -ResourceGroupName $rgName -ErrorAction SilentlyContinue
    if ($null -eq $publicIp) {
        Write-Log "Creating Public IP '$publicIpName'..."
        $publicIp = New-AzPublicIpAddress -Name $publicIpName `
            -ResourceGroupName $rgName -Location $location `
            -AllocationMethod Static -Sku Standard
        Write-Log "Public IP '$publicIpName' created successfully."
    } else {
        Write-Log "Public IP '$publicIpName' already exists. Skipping creation."
    }

    # --- NIC Creation ---
    $nic = Get-AzNetworkInterface -Name $nicName -ResourceGroupName $rgName -ErrorAction SilentlyContinue
    if ($null -eq $nic) {
        Write-Log "Creating NIC '$nicName'..."
        $nic = New-AzNetworkInterface -Name $nicName `
            -ResourceGroupName $rgName -Location $location `
            -Subnet $subnet -NetworkSecurityGroup $nsg -PublicIpAddress $publicIp
        Write-Log "NIC '$nicName' created successfully. ID: $($nic.Id)"
    } else {
        Write-Log "NIC '$nicName' already exists. Skipping creation."
    }

    Write-Log "Network interface creation completed successfully."
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
