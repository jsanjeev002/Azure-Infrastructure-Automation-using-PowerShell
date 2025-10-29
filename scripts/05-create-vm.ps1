<#
.SYNOPSIS
    Creates a Windows Virtual Machine in Azure.

.DESCRIPTION
    This script creates a Windows VM with a specified NIC.
    Includes parameter validation, idempotent checks, logging, and error handling.
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
    [string]$vmName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$nicName,

    [Parameter(Mandatory = $false)]
    [string]$vmSize = "Standard_B1s",

    [Parameter(Mandatory = $false)]
    [string]$imagePublisher = "MicrosoftWindowsServer",

    [Parameter(Mandatory = $false)]
    [string]$imageOffer = "WindowsServer",

    [Parameter(Mandatory = $false)]
    [string]$imageSku = "2022-datacenter",

    [Parameter(Mandatory = $false)]
    [string]$logFile = ".\VMCreation.log"
)

# --- Configuration ---
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Logging function ---
function Write-Log {
    param([string]$message)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $entry = "[$timestamp] $message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

try {
    Write-Log "Starting VM creation process for '$vmName'..."

    # --- Validate NIC ---
    $nic = Get-AzNetworkInterface -Name $nicName -ResourceGroupName $rgName -ErrorAction SilentlyContinue
    if (-not $nic) {
        throw "Network Interface '$nicName' not found in resource group '$rgName'."
    }
    Write-Log "Using existing NIC '$nicName' (ID: $($nic.Id))"

    # --- Check if VM already exists ---
    $existingVM = Get-AzVM -Name $vmName -ResourceGroupName $rgName -ErrorAction SilentlyContinue
    if ($existingVM) {
        Write-Log "VM '$vmName' already exists. Skipping creation."
        return
    }

    # --- Credentials ---
    $cred = Get-Credential -Message "Enter username and password for the VM"
    Write-Log "Credentials captured."

    # --- Build VM Configuration ---
    Write-Log "Creating VM configuration..."
    $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize |
        Set-AzVMOperatingSystem -Windows -ComputerName $vmName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate |
        Set-AzVMSourceImage -PublisherName $imagePublisher -Offer $imageOffer -Skus $imageSku -Version "latest" |
        Add-AzVMNetworkInterface -Id $nic.Id

    # --- Create the VM ---
    Write-Log "Deploying VM '$vmName' in '$location'..."
    New-AzVM -ResourceGroupName $rgName -Location $location -VM $vmConfig | Out-Null
    Write-Log "VM '$vmName' created successfully."

    Write-Log "VM creation process completed successfully."
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
