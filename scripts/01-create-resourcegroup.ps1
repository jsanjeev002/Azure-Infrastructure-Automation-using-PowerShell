$rgName = "CloudInfraRG"
$location = "EastUS"

New-AzResourceGroup -Name $rgName -Location $location
Write-Host "Resource group '$rgName' created in $location"
