# 03-create-nsg.ps1
$rgName = "CloudInfraRG"
$nsgName = "CloudNSG"
$location = "EastUS"

$nsgRule = New-AzNetworkSecurityRuleConfig -Name "AllowRDP" `
  -Protocol "Tcp" -Direction "Inbound" -Priority 1000 -SourceAddressPrefix * `
  -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow

$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $rgName `
  -Location $location -Name $nsgName -SecurityRules $nsgRule

Write-Host "Network Security Group '$nsgName' created with RDP access."
