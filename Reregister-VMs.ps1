param (
    [String] $Server = $(Read-Host "FQDN of the vCenter Server?"),
    [String] $Datastore,
    [String] $FilePath = $(Read-Host "File path?"),
    [Switch] $Restore,
    [Switch] $PowerOn
)

# If the user specified export
If (!$Restore.IsPresent) {
    ## and did not specify the Datastore parameter, prompt for it
    If (!$Datastore) {
        $Datastore = Read-Host "Datastores to index? (* for all datastores)"
    }
}

# Connect to vCenter
$myViConnection = Connect-VIServer -Server $Server

# If we're exporting
If (!$Restore.IsPresent) {
    Write-Output "Exporting VMs and VMX paths..."
    ## Get the user specified datastore(s)
    $myDatastores = Get-Datastore -Name $Datastore
    ## Get VMs on the specified datastore(s)
    $myDSVMs = $myDatastores | Get-VM
    ## Export the VM Name and VMX Path to a CSV on the user specified path
    $myDSVMs | Select Name, PowerState, @{N="VmxPath";E={$_.Extensiondata.Summary.Config.VmPathName}} | Export-Csv -NoTypeInformation -Path $FilePath -NoClobber
}

# If we're restoring
If ($Restore.IsPresent) {
    ## Read in the user specified CSV file.
    $myVMs = Import-CSV -Path $FilePath
    ## ForEach VM in the CSV file
    ForEach ($VM in $myVMs) {
        ### Get the datastore name from the VM in the CSV file
        $targetDS = $VM.VmxPath.Substring($VM.VmxPath.indexof('[')+1,$VM.VmxPath.indexof(']')-1)
        ### Select the first host with access to the specified datastore
        $targetHost = Get-Datastore -Name $targetDS | Get-VMHost | Select-Object -First 1
        ### Register the VM on the specifed vmhost
        Write-Output "Registering VM $($VM.Name) to VMHost $($targetHost.Name)"
        $registeredVM = New-VM -VMFilePath $VM.VmxPath -Confirm:$false -VMHost $targetHost
        ### If the user specified PowerOn parameter and the VM was on during export
        If ($PowerOn -and ($VM.PowerState -eq 'PoweredOn')) {
            Write-Host "Powering on $($registeredVM.Name)..."
            #### Power on the registered VM
            $registeredVM | Start-VM -Confirm:$false | Out-Null
            #### Execute any DRS recommendations (in case the cluster is in PA mode)
            $targetHost | Get-Cluster | Get-DrsRecommendation | Invoke-DrsRecommendation
        }
    }
}
Write-Output "Done."
# Disconnect from the vCenter
Disconnect-VIServer -Server $Server -Confirm:$false
