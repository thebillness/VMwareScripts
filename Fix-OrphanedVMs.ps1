Param(
    ## Get confirmation?
    [bool]$Confirm = $true,
    ## Boot the VM when we're done?
    [Bool]$BootVM = $false   
)

# Get a View of all the VMs with an orphaned connection state
#$myView = Get-View -ViewType VirtualMachine | Where-Object {$_.Runtime.ConnectionState -eq "orphaned"}
$myView = Get-View -ViewType VirtualMachine | Where-Object {$_.Runtime.ConnectionState -eq "inaccessible"}
# Assemble the needed data from each VM in the view
$myVMs = $myView | % {Get-VM -Name $_.Name |Select-Object Name,VMHost,FolderID,@{E={$_.ExtensionData.Config.Files.VmPathName};L="VMXPath"}}
# Tell the user what we're about to do
Write-Output "Preparing to act on these VMs:"
$myVMs | Select-Object Name,VMHost,VMXPath
# Allow the user the chance to cancel
If ($confirm) {$null = Read-Host "Press Enter to continue"}
# Remove the orphaned VMs from inventory
Write-Output "Removing orphaned VMs from inventory..."
$myVMs | ForEach-Object {Remove-VM -Confirm:$false -VM (Get-VM -Name $_.Name)}
# Add the VMs back to inventory
Write-Output "Adding VMs back to inventory..."
$resultVMs = $myVMs | %{New-VM -VMFilePath $_.VMXPath -VMHost $_.VMHost -Location (Get-Folder -Id $_.FolderID)}
# If requested, power on VMs
If ($BootVM) {
	Write-Output "Booting VMs..."
	$resultVMs | Start-VM -Confirm:$false
}