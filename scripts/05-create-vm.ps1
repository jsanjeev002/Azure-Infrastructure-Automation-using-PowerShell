# 04-create-vm.ps1 (Part 2)
$cred = Get-Credential -Message "Enter username and password for the VM"

$vmConfig = New-AzVMConfig -VMName $vmName -VMSize "Standard_B1s" |
  Set-AzVMOperatingSystem -Windows -ComputerName $vmName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate |
  Set-AzVMSourceImage -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus "2022-datacenter" -Version "latest" |
  Add-AzVMNetworkInterface -Id $nic.Id

New-AzVM -ResourceGroupName $rgName -Location $location -VM $vmConfig

Write-Host "Virtual Machine '$vmName' created successfully!"
