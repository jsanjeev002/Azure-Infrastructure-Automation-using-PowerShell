<#
.SYNOPSIS
    Automates Azure Blob Storage setup and file operations.
.DESCRIPTION
    - Creates storage account and blob container if not existing
    - Uploads and downloads files safely
    - Self-contained: includes its own logging and error handling
.EXAMPLE
    .\05-Blob-Automation.ps1 -rgName "CloudInfraRG" -location "EastUS" -storageName "cloudinfrastorage001" -containerName "files" -filePath "./sample.txt"
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$rgName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$location,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9]{3,24}$', ErrorMessage = "Storage account name must be lowercase alphanumeric, 3–24 chars.")]
    [string]$storageName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$containerName,

    [Parameter(Mandatory = $false)]
    [string]$filePath = ".\sample.txt",

    [Parameter(Mandatory = $false)]
    [string]$logFile = ".\BlobAutomation.log"
)

# --- Settings ---
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Logging helper ---
function Write-Log {
    param([string]$message, [string]$level = "INFO")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $entry = "[$timestamp][$level] $message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

# --- Safe execution helper ---
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

# --- Start ---
Write-Log "Starting Blob Storage automation..."
Write-Log "Resource Group: $rgName | Location: $location | Storage: $storageName | Container: $containerName"

# --- Step 1: Create or get Storage Account ---
Run-Safely {
    $existingStorage = Get-AzStorageAccount -ResourceGroupName $rgName -Name $storageName -ErrorAction SilentlyContinue
    if (-not $existingStorage) {
        Write-Log "Creating new storage account '$storageName'..."
        $global:storageAcc = New-AzStorageAccount -ResourceGroupName $rgName -Name $storageName `
            -Location $location -SkuName "Standard_LRS" -Kind "StorageV2"
        Write-Log "Storage account '$storageName' created successfully."
    } else {
        Write-Log "Storage account '$storageName' already exists. Using existing one."
        $global:storageAcc = $existingStorage
    }
} "Failed to create or retrieve storage account"

# --- Step 2: Create or get container ---
Run-Safely {
    $ctx = $storageAcc.Context
    $existingContainer = Get-AzStorageContainer -Name $containerName -Context $ctx -ErrorAction SilentlyContinue
    if (-not $existingContainer) {
        Write-Log "Creating container '$containerName'..."
        New-AzStorageContainer -Name $containerName -Context $ctx -Permission Blob | Out-Null
        Write-Log "Container '$containerName' created successfully."
    } else {
        Write-Log "Container '$containerName' already exists."
    }
} "Failed to create or retrieve blob container"

# --- Step 3: Upload file ---
Run-Safely {
    if (-not (Test-Path $filePath)) {
        Write-Log "File '$filePath' does not exist. Creating a sample file..."
        Set-Content -Path $filePath -Value "This is a test file for blob upload."
    }

    Write-Log "Uploading file '$filePath' to container '$containerName'..."
    Set-AzStorageBlobContent -File $filePath -Container $containerName `
        -Blob (Split-Path $filePath -Leaf) -Context $ctx -Force | Out-Null
    Write-Log "File uploaded successfully."
} "Failed to upload file to blob storage"

# --- Step 4: Download file and verify ---
Run-Safely {
    $downloadedPath = Join-Path (Split-Path $filePath -Parent) "downloaded_$(Split-Path $filePath -Leaf)"
    Write-Log "Downloading blob to '$downloadedPath'..."
    Get-AzStorageBlobContent -Blob (Split-Path $filePath -Leaf) -Container $containerName `
        -Destination $downloadedPath -Context $ctx -Force | Out-Null

    if (Test-Path $downloadedPath) {
        Write-Log "File downloaded successfully to '$downloadedPath'."
    } else {
        throw "Download verification failed. File not found at $downloadedPath."
    }
} "Failed to download or verify blob"

Write-Log "✅ Blob Storage automation completed successfully!"
