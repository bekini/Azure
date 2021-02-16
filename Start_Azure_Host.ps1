#!/usr/bin/pwsh
$AzureHost=$args[0]

echo "Debug powershell : Start-AzVM -Confirm:$false  -Name $AzureHost -ResourceGroupName SCAP-BUILD-MACHINES"
Start-AzVM -Confirm:$false  -Name $AzureHost -ResourceGroupName SCAP-BUILD-MACHINES


