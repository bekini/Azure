#!/usr/bin/pwsh
$AzureHost=$args[0]

echo "DEBUG -Powershell:  Stop-AzVM -Force -Name $AzureHost -ResourceGroupName SCAP-BUILD-MACHINES"
Stop-AzVM -Force -Name $AzureHost -ResourceGroupName SCAP-BUILD-MACHINES


