Param(
    # Disable the Network Introspection service? (Default: $false)
    [bool]$DisableNI = $false,
    # Get-VM Name filter for selecting VMs
    [Parameter(Mandatory=$true)] [string]$VMName
)

# Get all Powered On, Windows guest VMs matching the provided Name filter
Write-Output "Gathering VMs..."
$targetVMs = Get-VM -Name $VMName -Server * | Where-Object {$_.PowerState -match "on" -and $_.ExtensionData.Config.GuestFullName -match "win"} | Sort-Object -Property Name
Write-Output "Done."

# Initialize hash tables
$failedDetection = @()
$outputTable = @()

# For Each selected VM
ForEach ($vm in $targetVMs) {
	## Give output and initialize variables
    Write-Output "$($vm.Name) - Checking..."
    $myDetection = $null
    $modulePresent = $null
    $moduleRunning = $null
    $moduleEnabled = $null
	## Query VM for the Network Introspection service
    $myDetection = Get-Service vnetwfp -ComputerName $vm.Name
	## If nothing is returned from the service query
    If (-not $myDetection) {
		### No service was found, set flags
        Write-Verbose "$($vm.Name) - Module not present"
        $modulePresent = $false
        $moduleRunning = $false
        $moduleEnabled = $false
    } else {
	## Otherwise, the service was found. Give verbose output, set flags and interogate the configuration of the service. 
        Write-Verbose "$($vm.Name) - Module present"
		$modulePresent = $true
		### If the service is not disabled, give verbose out put and set flag
        If ($myDetection.StartType -ne "DISABLED") {
            Write-Verbose "$($vm.Name) - Module enabled on reboot."
            $moduleEnabled = $true
        } else {
		### Otherwise, the service is disabled, give verbose output and set flag
            Write-Verbose "$($vm.Name) - Module disabled on reboot."
            $moduleEnabled = $false
        }
		### If the service is running, give verbose output and set flag
        If ($myDetection.Status -match "RUNNING") {         
            Write-Verbose "$($vm.Name) - Module running."
			$moduleRunning = $true
        } elseIf ($myDetection.Status -match "STOPPED") {
        ### Otherwise, if the service is stopped, give verbose output and set flag
            Write-Verbose "$($vm.Name) - Module stopped."
			$moduleRunning = $false
        } else {
		### Otherwise, give verbose output that the state could not be determined. 
            Write-Output "$($vm.Name) - Could not determine module state."
        }
    }
	
	## Initialize flag
    $disableAttempt = "None"
	## If the user requested to stop NI and the module is running or enabled
    If ($disableNI -and ($moduleRunning -or $moduleEnabled)) {
		### Disable and stop the service, then get the service again to check for success.
        $myresult = $null
        $myResult = Get-Service vnetwfp -ComputerName $vm.Name | Set-Service -StartupType Disabled -PassThru -ComputerName $vm.Name | Stop-Service -PassThru | Get-Service -ComputerName $vm.Name 
		### If the service is now stopped and disabled, give success output and set flag.
        If ($myResult.Status -eq "STOPPED" -and $myResult.StartType -eq "DISABLED") {
            Write-Output "$($vm.Name) - Module successfully stopped and disabled."
            $disableAttempt = "Successful"
        } else {
		### Otherwise, give failure output and set flag
            Write-Error "$($vm.Name) - Failed to stop and disable module."
            $disableAttempt = "Failed"
        }
    }
	## Add VMName, FQDN and all flags to output table
    $outputTable += ""| Select-object @{N='Name';E={$vm.Name}},@{N='FQDN';E={$vm.ExtensionData.Guest.IPStack[0].DnsConfig.HostName,$vm.ExtensionData.Guest.IPStack[0].DnsConfig.DomainName -join '.'}},@{N='ModulePresent';E={$modulePresent}},@{N='ModuleEnabled';E={$moduleEnabled}},@{N='ModuleRunning';E={$moduleRunning}},@{N='DisableAttempt';E={$disableAttempt}}
}

# Give final output table
$outputTable
