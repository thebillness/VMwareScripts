$myvCenterServer = "vcenter.wall.lab" # Single vCenter required, always use FQDN
$myHostFilter = "esx-lab-*" # Hosts to include
$myPatchedHosts = "C:\Lab\VMware\patched.csv" # File path to record successful date of patching
$myBaselineGroup = "Nimble|UCS Driver|Critical" # Host Baselines to include

If (-not $myCredential) {$myCredential = Get-Credential -Message "vCenter administrator credential:"}

# Connect To vCenter
Connect-VIServer -Server $myvCenterServer -Credential $myCredential #-AllLinked:$true
# Get a list of hosts that are connected or in maintenance mode
$myVMHosts = Get-VMHost -Name $myHostFilter -Server * | Where-Object {$_.ConnectionState -match "Maintenance|Connected"} | Sort-Object -Property $_.Name
# Get the Alarm Manager
$myAlarmManager = Get-View AlarmManager
# For Each Host
ForEach ($vmHost in $myVMHosts) {
	$myRDMs = $null
	## Get RDMs
	$myRDMs = Get-VM -Location $vmHost | Get-HardDisk | Where-Object {$_.DiskType -match '^Raw'} | Select-Object -ExpandProperty ScsiCanonicalName -First 1
	## If it has RDMs, we're probably housing a Windows cluster.
	If ($myRDMs) {
		###  Skip the host until we can verify the node is not active.
		Write-Host "($($vmHost.Name)) VMs with RDMs detected. Skipping host."
		continue 
	}
	## No, RDMs.
	## Check for patches
	Write-Host "($($vmHost.Name)) Patching..."
	## Get the Host baselines specified in $myBaselineGroup
	$myBaseline = Get-Baseline -TargetType Host | Where-Object {$_.Name -match $myBaselineGroup}
	## Check compliance for the baselines
	$myCompliance = Get-Compliance -Entity $vmHost -Baseline $myBaseline
	## If host is not Compliant with all baselines
	If ($myCompliance.Status -ne "Compliant") {
		### Patch the host
		### Enable maintenance mode
		Write-Host "($($vmHost.Name)) Enable Maintenance Mode..."
		$vmHost | Set-VMHost -State Maintenance -Confirm:$false -Evacuate:$true | Out-Null
		### Disable alarm actions
		$myAlarmManager.EnableAlarmActions($vmHost.ExtensionData.MoRef,$false)
		Start-Sleep -Seconds 1
		### Wait until the host is in Maintenance mode
		While ((Get-VMHost -Name $vmHost.Name -Server *).ConnectionState -ne "Maintenance") {
			Start-Sleep -Seconds 1
		}
		### Install patches
		Write-Host "($($vmHost.Name)) Installing patches..."
		Update-Entity -Baseline $myBaseline -Entity $VMHost -ClusterDisableHighAvailability:$true -Confirm:$false
		### Wait until the host is in Maintenance mode
		Write-Host "($($vmHost.Name)) Waiting for the host to return..."
		While ((Get-VMHost -Name $vmHost.Name -Server *).ConnectionState -ne "Maintenance") {
			Start-Sleep -Seconds 1
		}
		### Installation complete
		Write-Host "($($vmHost.Name)) Installation complete."
		### Disable maintenance mode
		Write-Host "($($vmHost.Name)) Disabling Maintenance Mode..."
		$vmHost | Set-VMHost -State Connected -Confirm:$false | Out-Null
		### Enable alarm actions
		$myAlarmManager.EnableAlarmActions($vmHost.ExtensionData.MoRef,$true)
		### Record a log item stating the patch date
		Add-Content "$($vmHost.Name),$((Get-date -Format yyyy-MM-dd))" -Path $myPatchedHosts
    	} else {
		## else, Host is compliant with all baselines, no patches available
		Write-Host "($($vmHost.Name)) No patches available."
	}
	## We're done with this host, tell the user and allow them to proceed
	Write-Host "($($vmHost.Name)) All tasks complete."
	Read-Host -Prompt "Press Enter to continue..." ####
}

# We're all done, disconnect from vCenter.
Disconnect-VIServer -Server * -Confirm:$false
