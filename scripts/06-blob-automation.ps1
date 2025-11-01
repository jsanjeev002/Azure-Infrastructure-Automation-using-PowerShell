<#
.SYNOPSIS
    Automates Azure Blob Storage setup, access control, and file operations.

.DESCRIPTION
    - Creates resource group if missing
    - Creates storage account and blob container (public or private)
    - Uploads and downloads a file with verification
    - Handles input validation, logging, and errors gracefully
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$rgName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$location,

    [Parameter(Mandatory = $false)]
    [string]$filePath = ".\sample.txt",

    [Parameter(Mandatory = $false)]
    [string]$logFile = ".\BlobAutomation.log"
)

# =======================
# Script Configuration
# =======================
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Write-Host "`n=== Azure Blob Storage Automation ===" -ForegroundColor Cyan

# =======================
# Logging Helper
# =======================
function Write-Log {
    param([string]$message, [string]$level = "INFO")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $entry = "[$timestamp][$level] $message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

# =======================
# Safe Execution Wrapper
# =======================
function Run-Safely {
    param(
        [scriptblock]$Action,
        [string]$ErrorMessage
    )
    try {
        & $Action
    } catch {
        Write-Log "$ErrorMessage : $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

# =======================
# User Inputs
# =======================
do {
    $storageName = Read-Host "Enter a name for the Storage Account (3–24 lowercase letters/numbers)"
    if ($storageName -notmatch '^[a-z0-9]{3,24}$') {
        Write-Host "❌ Invalid name. Use only lowercase letters or numbers, 3–24 chars long." -ForegroundColor Red
        $storageName = $null
    }
} until ($storageName)

do {
    $containerName = Read-Host "Enter a name for the Blob Container"
    if ([string]::IsNullOrWhiteSpace($containerName)) {
        Write-Host "❌ Container name cannot be empty." -ForegroundColor Red
        $containerName = $null
    }
} until ($containerName)

$allowPublic = Read-Host "Do you want to enable public access for the blob container? (yes/no)"

Write-Log "🚀 Starting Blob Storage automation..."
Write-Log "Resource Group: $rgName | Location: $location | Storage: $storageName | Container: $containerName"

# =======================
# Step 0: Ensure Resource Group
# =======================
Run-Safely {
    $existingRG = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
    if (-not $existingRG) {
        Write-Log "📦 Resource group '$rgName' not found. Creating new one..."
        New-AzResourceGroup -Name $rgName -Location $location | Out-Null
        Write-Log "✅ Resource group '$rgName' created successfully."
    } else {
        Write-Log "Resource group '$rgName' already exists. Skipping creation."
    }
} "❌ Failed to verify or create resource group"

# =======================
# Step 1: Create Storage Account
# =======================
$storageAcc = Run-Safely {
    $existing = Get-AzStorageAccount -ResourceGroupName $rgName -Name $storageName -ErrorAction SilentlyContinue
    if (-not $existing) {
        Write-Log "Creating storage account '$storageName' in $location..."
        if ($allowPublic -eq "yes") {
            New-AzStorageAccount -ResourceGroupName $rgName `
                                 -Name $storageName `
                                 -Location $location `
                                 -SkuName "Standard_LRS" `
                                 -Kind "StorageV2" `
                                 -AllowBlobPublicAccess $true
        } else {
            New-AzStorageAccount -ResourceGroupName $rgName `
                                 -Name $storageName `
                                 -Location $location `
                                 -SkuName "Standard_LRS" `
                                 -Kind "StorageV2" `
                                 -AllowBlobPublicAccess $false
        }
    } else {
        Write-Log "Storage account '$storageName' already exists. Using existing one."
        return $existing
    }
} "❌ Failed to create or retrieve storage account"

# Ensure Context
$ctx = $storageAcc.Context
if (-not $ctx) {
    $ctx = (Get-AzStorageAccount -ResourceGroupName $rgName -Name $storageName).Context
}

# =======================
# Step 2: Create Container
# =======================
Run-Safely {
    $existingContainer = Get-AzStorageContainer -Name $containerName -Context $ctx -ErrorAction SilentlyContinue
    if (-not $existingContainer) {
        if ($allowPublic -eq "yes") {
            Write-Log "🪣 Creating public container '$containerName'..."
            New-AzStorageContainer -Name $containerName -Context $ctx -Permission Blob | Out-Null
        } else {
            Write-Log "🪣 Creating private container '$containerName'..."
            New-AzStorageContainer -Name $containerName -Context $ctx -Permission Off | Out-Null
        }
        Write-Log "✅ Container '$containerName' created successfully."
    } else {
        Write-Log "Container '$containerName' already exists."
    }
} "❌ Failed to create or retrieve blob container"

# =======================
# Step 3: Upload File
# =======================
Run-Safely {
    if (-not (Test-Path $filePath)) {
        Write-Log "File '$filePath' not found. Creating a sample file..."
        Set-Content -Path $filePath -Value "This is a test file for blob upload."
    }

    Write-Log "Uploading '$filePath' to '$containerName'..."
    Set-AzStorageBlobContent -File $filePath -Container $containerName `
        -Blob (Split-Path $filePath -Leaf) -Context $ctx -Force | Out-Null
    Write-Log "✅ File uploaded successfully."
} "❌ Failed to upload file to blob storage"

# =======================
# Step 4: Download + Verify
# =======================
Run-Safely {
    $downloadedPath = Join-Path (Split-Path $filePath -Parent) "downloaded_$(Split-Path $filePath -Leaf)"
    Write-Log "Downloading blob to '$downloadedPath'..."
    Get-AzStorageBlobContent -Blob (Split-Path $filePath -Leaf) -Container $containerName `
        -Destination $downloadedPath -Context $ctx -Force | Out-Null

    if (Test-Path $downloadedPath) {
        Write-Log "✅ File downloaded successfully to '$downloadedPath'."
    } else {
        throw "Download verification failed. File not found."
    }
} "❌ Failed to download or verify blob"

# =======================
# Complete
# =======================
Write-Log "🎯 Blob Storage automation completed successfully!"
Write-Host "`n✅ All operations completed successfully!" -ForegroundColor Green
