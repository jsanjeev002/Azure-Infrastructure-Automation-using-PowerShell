# 02-create-network.ps1
$rgName = "CloudInfraRG"
$vnetName = "CloudVNet"
$subnetName = "CloudSubnet"
$location = "EastUS"

$vnet = New-AzVirtualNetwork -ResourceGroupName $rgName -Location $location `
  -Name $vnetName -AddressPrefix "10.0.0.0/16"

Add-AzVirtualNetworkSubnetConfig -Name $subnetName `
  -AddressPrefix "10.0.1.0/24" -VirtualNetwork $vnet

$vnet | Set-AzVirtualNetwork
Write-Host "Virtual Network '$vnetName' with Subnet '$subnetName' created."
