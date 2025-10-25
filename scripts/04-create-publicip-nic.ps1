# 04-create-vm.ps1 (Part 1)
$rgName = "CloudInfraRG"
$location = "EastUS"
$vmName = "CloudVM"
$vnetName = "CloudVNet"
$subnetName = "CloudSubnet"
$nsgName = "CloudNSG"
$publicIpName = "CloudPublicIP"
$nicName = "CloudNIC"

$subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork (Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName)
$nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rgName
$publicIp = New-AzPublicIpAddress -Name $publicIpName -ResourceGroupName $rgName `
  -Location $location -AllocationMethod Static -Sku Basic

$nic = New-AzNetworkInterface -Name $nicName -ResourceGroupName $rgName -Location $location `
  -Subnet $subnet -NetworkSecurityGroup $nsg -PublicIpAddress $publicIp
