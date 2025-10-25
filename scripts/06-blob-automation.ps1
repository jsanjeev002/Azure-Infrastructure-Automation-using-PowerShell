# 05-blob-automation.ps1
$rgName = "CloudInfraRG"
$location = "EastUS"
$storageName = "cloudinfra$(Get-Random)"
$containerName = "files"

# Create storage account
$storageAcc = New-AzStorageAccount -ResourceGroupName $rgName -Name $storageName `
  -Location $location -SkuName "Standard_LRS" -Kind "StorageV2"

# Create blob container
$ctx = $storageAcc.Context
New-AzStorageContainer -Name $containerName -Context $ctx -Permission Blob

# Upload and download a file
Set-Content -Path "./sample.txt" -Value "This is a test file for upload."
Set-AzStorageBlobContent -File "./sample.txt" -Container $containerName -Blob "sample.txt" -Context $ctx

Get-AzStorageBlobContent -Blob "sample.txt" -Container $containerName -Destination "./downloaded_sample.txt" -Context $ctx

Write-Host "Blob upload/download automation completed successfully."
