<#
.SYNOPSIS
    Creates a Windows Virtual Machine in Azure with automatic fallback handling.

.DESCRIPTION
    This script creates a Windows VM with a specified NIC and automatically retries 
    with alternative VM sizes or regions if Azure capacity issues occur.
    Includes parameter validation, idempotent logic, structured logging, and error handling.
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

    # --- Build Base VM Config (without size) ---
    Write-Log "Creating base VM configuration..."
    $baseVMConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize |
        Set-AzVMOperatingSystem -Windows -ComputerName $vmName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate |
        Set-AzVMSourceImage -PublisherName $imagePublisher -Offer $imageOffer -Skus $imageSku -Version "latest" |
        Add-AzVMNetworkInterface -Id $nic.Id

    # --- Fallback Configuration ---
    $fallbackSizes = @("Standard_B2s", "Standard_D2s_v3", "Standard_A2_v2")

    function Try-DeployVM {
        param (
            [string]$region,
            [string]$size
        )

        Write-Log "Attempting deployment in '$region' with size '$size'..."
        try {
            $vmConfig = $baseVMConfig
            $vmConfig.HardwareProfile.VmSize = $size
            New-AzVM -ResourceGroupName $rgName -Location $region -VM $vmConfig -ErrorAction Stop | Out-Null
            Write-Log "✅ VM '$vmName' deployed successfully in '$region' using size '$size'."
            return $true
        }
        catch {
            $errMsg = $_.Exception.Message
            Write-Log "⚠️ Deployment failed in '$region' with size '$size': $errMsg"

            if ($errMsg -match "SkuNotAvailable") {
                Write-Log "❌ Capacity issue detected for '$size' in '$region'. Trying fallback..."
                return $false
            }
            else {
                throw $_
            }
        }
    }

    # --- Initial Attempt ---
    if (-not (Try-DeployVM -region $location -size $vmSize)) {
        # Try fallback sizes in same region
        foreach ($size in $fallbackSizes) {
            if (Try-DeployVM -region $location -size $size) { exit 0 }
        }

        Write-Log "❌ All fallback attempts failed. No capacity found for your request."
        exit 1
    }

    Write-Log "✅ VM creation process completed successfully."
}
catch {
    Write-Log "❌ ERROR: $($_.Exception.Message)"
    exit 1
}


