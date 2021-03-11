Param(
    ## Are we just testing?
    [bool]$whatIf = $true,
    ## vCenter Server(s) to connect
    [string[]]$vCenterServer,
    ## VM names to modify
    [string[]]$VMInclude,
    ## Guest OS ID
    [int]$GuestID = "windows9Server64Guest",
    ## Boot the VM when we're done?
    [Bool]$BootVM = $false
    
)

## vCenter Server(s) to connect
If (-not $vCenterServer) {$vCenterServer = "vc1.domain.example","vc2.domain.example"}
## VM names to modify
If (-not $VMInclude) {$VMInclude = "BW-Test*"}
## Get vCenter Credential
If (-not $myCredential) {$myCredential = Get-Credential -Message "vCenter Server credential?"}

## Connect to vCenter Server(s)
try {
    Connect-VIServer -Server $vCenterServer -Credential $myCredential -ErrorAction Stop
} catch { 
    Write-Error "Could not connect to vCenter!"
    exit 1
}

Write-Host "Gathering VMs..."
$TargetVMs = Get-VM -Name $VMInclude -Server * | Where-Object {$_.PowerState -eq "PoweredOff" -and $_.GuestId -ne $GuestID} | Sort-Object -Property Name
If (-not $TargetVMs) {Write-Output "No VMs match current filters. (Name = $VMInclude, GuestOS != $GuestID, Powered Off)"; exit 1}
## Report filter information and VM Count to user
Write-Output "Filter Information: VM Name = $VMInclude, GuestOS != $GuestID, Powered Off, Testing = $whatIf"
## Double opt-in (Run script, confirm execution)
If ($whatIf) {$makeItHappen = Read-Host "Preparing to TEST $($TargetVMs.Count) VM(s). Continue? [y/N]"}
else {
    $makeItHappen = Read-Host "Preparing to modify $($TargetVMs.Count) VM(s). Continue? [y/N]"
}
If ($makeItHappen -ne "y" -and $makeItHappen -ne "yes") {
    Write-Output "Aborted by user."
    Disconnect-VIServer -Server $vCenterServer -Confirm:$false
    exit 1
}

## Provide status
$TheTime = Get-Date	
Write-Output "$TheTime - Starting..."

If ($whatIf) {
    ## If testing, say what will happen
    $TargetVMs | ForEach-Object {Write-Output "[WhatIf] $($_.Name) - Set vCPU from $($_.NumCpu) to $TotalvCPU"}
} else {
    ## if not testing, execute the vCPU change
    $DestinationVMs = $TargetVMs | Set-VM -NumCpu $TotalvCPU -Confirm:$false -ErrorAction SilentlyContinue | Sort-Object -Property Name
    ## Verify what happened
    foreach ($vm in $TargetVMs) {
        ## Compare result to target
        $result = $DestinationVMs | Where-Object {$_.Name -eq $vm.Name}
        If ($result) {
            ## If a result exists, compare vCPU numbers to our request
            If ($result.NumCpu -eq $TotalvCPU) {
                ## If current vCPU matches out request, report success and optionally boot the VM
                Write-Output "[Success] $($vm.Name) - Set vCPU from $($vm.NumCpu) to $TotalvCPU"
                if ($BootVM) {Start-VM -VM $vm -Confirm:$false -RunAsync}
            } else {
                ## if the current vCPU count does NOT match our request, report failure, NEVER boot the VM.
                Write-Output "[FAILURE] $($vm.Name) - Set vCPU from $($vm.NumCpu) to $TotalvCPU"
            }
        } else {
            ## If a result does not exist, report failure.
            Write-Output "[FAILURE] $($vm.Name) - Set vCPU from $($vm.NumCpu) to $TotalvCPU"
        }
    }
}
## We're done, report and clean up
$TheTime = Get-Date
Write-Host "$TheTime - All tasks complete."
Disconnect-VIServer -Server $vCenterServer -Confirm:$false
