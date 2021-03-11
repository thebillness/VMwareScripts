Param(
    # Disable the Network Introspection service? (Default: $false)
    [bool]$DisableGI = $false,
    # Get-VM Name filter for selecting VMs
    [Parameter(Mandatory=$true)] [string]$VMName
)

# Get all Powered On, Windows guest VMs matching the provided Name filter
Write-Output "Gathering VMs..."
$targetVMs = Get-VM -Name $VMName -Server * | Where-Object {$_.PowerState -match "on" -and $_.ExtensionData.Config.GuestFullName -match "win"} | Sort-Object -Property Name
Write-Output "Done."

# Initialize hash table
$outputTable = @()

# For Each selected VM
ForEach ($vm in $targetVMs) {
	## Give output and initialize variables
    Write-Output "$($vm.Name) - Checking..."
    $myDetection = $null
    $CSPresent = $null
    $CSRunning = $null
    $myGIDetection = $null
    $modulePresent = $null
    $moduleEnabled = $null
    $moduleRunning = $null
	## Query VM for the Network Introspection service
    $myDetection = Get-Service CSFalconService -ComputerName $vm.Name
	## If nothing is returned from the service query
    If (-not $myDetection) {
		### No service was found, set flags
        Write-Verbose "$($vm.Name) - CS not present"
        $CSPresent = $false
        $CSRunning = $false
    } else {
	## Otherwise, the service was found. Give verbose output, set flags and interogate the configuration of the service. 
        Write-Verbose "$($vm.Name) - CS present"
		$CSPresent = $true
        ### If the service is running, give verbose output and set flag
        If ($myDetection.Status -match "RUNNING") {         
            Write-Verbose "$($vm.Name) - CS running."
			$CSRunning = $true
        } else {
		### Otherwise, give verbose output that the state could not be determined. 
            Write-Output "$($vm.Name) - Could not determine CS state."
        }
    }
    $myGIDetection = Get-Service vsepflt -ComputerName $vm.Name 
    If (-not $myGIDetection){
        ### No key was found, set flags
        Write-Verbose "$($vm.Name) - GI module not present"
        $modulePresent = $false
        $moduleEnabled = $false
        $moduleRunning = $false
    } else {
	    ## Otherwise, the service was found. Give verbose output, set flags and interogate the configuration of the service. 
        Write-Verbose "$($vm.Name) - GI module present"
        $modulePresent = $true
        ### If the service is not disabled, give verbose out put and set flag
        If ($myGIDetection.StartType -ne "DISABLED") {
            Write-Verbose "$($vm.Name) - GI module enabled on reboot."
            $moduleEnabled = $true
        } else {
        ### Otherwise, the service is disabled, give verbose output and set flag
            Write-Verbose "$($vm.Name) - GI module disabled on reboot."
            $moduleEnabled = $false
        }
        ### If the service is running, give verbose output and set flag
        If ($myGIDetection.Status -match "RUNNING") {         
            Write-Verbose "$($vm.Name) - GI module running."
            $moduleRunning = $true
        } elseIf ($myGIDetection.Status -match "STOPPED") {
        ### Otherwise, if the service is stopped, give verbose output and set flag
            Write-Verbose "$($vm.Name) - GI module stopped."
            $moduleRunning = $false
        } else {
        ### Otherwise, give verbose output that the state could not be determined. 
            Write-Output "$($vm.Name) - Could not determine GI module state."
        }
    }

	## Initialize flag
    $disableAttempt = "None"
	## If the user requested to stop NI and the module is running or enabled
    If ($disableGI -and $CSRunning -and $moduleEnabled) {
		### Disable the GI module, then get the setting again to check for success.
        $myresult = $null
        #Set-ItemProperty -ComputerName $vm.Name -Path "HKLM:\SYSTEM\CurrentControlSet\services\vsepflt\" -Name "Start" -Value 4
        $myResult = (Get-ItemProperty -ComputerName $vm.Name -Path "HKLM:\SYSTEM\CurrentControlSet\services\vsepflt\" -Name "Start").Start
        ################$myResult = Get-Service vsepflt -ComputerName $vm.Name | Set-Service -StartupType Disabled -PassThru -ComputerName $vm.Name | Stop-Service -PassThru | Get-Service -ComputerName $vm.Name 
		### If the service is now stopped and disabled, give success output and set flag.
        If ($myResult -eq 4) {
            Write-Output "$($vm.Name) - GI module successfully disabled. A reboot is required for the change to take effect."
            $disableAttempt = "Successful"
        } else {
		### Otherwise, give failure output and set flag
            Write-Error "$($vm.Name) - Failed to disable GI module."
            $disableAttempt = "Failed"
        }
    }
	## Add VMName, FQDN and all flags to output table
    $outputTable += ""| Select-object @{N='Name';E={$vm.Name}},@{N='FQDN';E={$vm.ExtensionData.Guest.IPStack[0].DnsConfig.HostName,$vm.ExtensionData.Guest.IPStack[0].DnsConfig.DomainName -join '.'}},@{N='CSPresent';E={$CSPresent}},@{N='CSRunning';E={$CSRunning}},@{N='GIPresent';E={$modulePresent}},@{N='GIEnabled';E={$moduleEnabled}},@{N='GIRunning';E={$moduleRunning}},@{N='GIDisableAttempt';E={$disableAttempt}}
}

# Give final output table
$outputTable | Format-Table

