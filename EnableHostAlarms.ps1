Param(
    ## Are we just testing?
    [bool]$WhatIf = $false,
    ## vCenter Server(s) to connect
    [string]$vCenterServer,
    ## VMHost names to modify
    [string]$VMHostInclude = "*",
	## Cluster to include
	[string]$ClusterInclude,
	[bool]$EnableActions = $true,
	[bool]$Confirm = $true
)

# Connect to vCenter
Try {
	Connect-VIServer -Server $vCenterServer -ErrorAction Stop
} Catch {
	# On failure, exit
	exit 1
}

# If ClusterInclude was provided
If ($ClusterInclude) {
	## Get the cluster matching provided input
	$myCluster = Get-Cluster -Name $ClusterInclude
	## From the selected cluste, get VMHosts matching the provided input
	$myVMHosts = Get-VMHost -Name $VMHostInclude -Location $myCluster
} else {
	# Otherwise, get VMHosts matching the provided input
	$myVMHosts = Get-VMHost -Name $VMHostInclude
}

$targedVMHosts = @()

# Get current alarm action state
ForEach ($myVMHost in $myVMHosts) {
	Write-Verbose "Getting current state..."
	## Get Alarm actions state
	If ($myAlarmManager.AreAlarmActionsEnabled($myVMHost.ExtensionData.MoRef) -eq $EnableActions) {
		Write-Verbose "[$($myVMHost.Name)] Success!"
		$targedVMHosts += $myVMHost | Select-Object Name,@{ Name = 'MoRef';  Expression = {$_.ExtensionData.MoRef}},@{ Name = 'CurrentState';  Expression = {$myAlarmManager.AreAlarmActionsEnabled($myVMHost.ExtensionData.MoRef)}},@{ Name = 'CurrentState';  Expression = {$myAlarmManager.AreAlarmActionsEnabled($myVMHost.ExtensionData.MoRef)}}
	} else {
		Write-Error "[$($myVMHost.Name)] Error setting Alarm Actions!"
		exit 1
	}
}


If ($confirm) {
	Write-Output "Conrimation - Set EnableActions to $EnableActions on the following VMHosts?"
	Write-Output "$($myVMH.Name)"
	$confirm = Read-Host "[N,y]"
}

# Set up the Alarm Managr
$myAlarmManager = Get-View AlarmManager

# For Each VMHost
ForEach ($myVMHost in $myVMHosts) {
	Write-Verbose "[$($myVMHost.Name)] Configuring alarm actions..."
	## Configure Alarm actions 
	$myAlarmManager.EnableAlarmActions($myVMHost.ExtensionData.MoRef,$EnableActions)
	If ($myAlarmManager.AreAlarmActionsEnabled($myVMHost.ExtensionData.MoRef) -eq $EnableActions) {
		Write-Verbose "[$($myVMHost.Name)] Success!"
	} else {
		Write-Error "[$($myVMHost.Name)] Error setting Alarm Actions!"
		exit 1
	}
}

## Disconnect from vCenter
Disconnect-VIServer -Server $vCenterServer -Confirm:$false
