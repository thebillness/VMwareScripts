###################################
# Get-UserEvents.ps1 - This script will determine if the two specified
# users are both acting on a VM in the specified time frame
#
# This script was writen as there was a concern two backup solutions were
# each backing up the same VMs. 
###################################

Param(
    # How far back to look
    [int]$DaysBack = 7,
    # The two users to search for
    [Parameter(Mandatory=$true)] [string]$User1,
    [Parameter(Mandatory=$true)] [string]$User2
)

# Get all VMs 
$VMs = Get-VM -Server *

# Initalize hash tables
$bothUsers = @()
$onlyUser1 = @()
$onlyUser2 = @()
$noUser =  @()

# For Each VM
ForEach ($vm in $VMs) {
	## Get all VM events going back the specified number of days
    $myEvents = Get-VIEvent -Entity $vm -Start (Get-Date).AddDays(-$DaysBack)
	## Initalize flags
    $bolUser1 = $false
    $bolUser2 = $false
    $user1Events = $null
    $user2Events = $null
	## Get User1 events
    $user1Events = $myEvents | Where-object {$_.UserName -match $User1}
	## Get User2 events
    $user2Events = $myEvents | Where-object {$_.UserName -match $User2}
    ## If User1 events were found, set User1 flag
	If ($user1Events) {$bolUser1 = $true}
	## If User2 events were found, set User2 flag
    If ($user2Events) {$bolUser2 = $true}
	## If both users have events on the VM, add the VM to the output table
    If ($bolUser1 -and $bolUser2) {
        $bothUsers += $vm
    }
}

# Provide output of the VMs
Write-Output "Both users have acted on these VMs in the last $DaysBack day(s):"
$bothUsers
