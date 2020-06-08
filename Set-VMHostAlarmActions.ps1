param (
    [Parameter(Mandatory=$true)] [object[]] $VMHost, # VMHost(s) to be configured
    [Parameter(Mandatory=$true)] [bool] $Enabled = $true # How to configure the alarm actions (Enabled: True/False)
)

# Invoke the Alarm Manager
$myAlarmManager = Get-View AlarmManager

## For Each $VMHost
ForEach ($targetHost in $VMHost) {
    ## Set the Alarm Managager to enabled/disabled for the requested VMHost
    $myAlarmManager.EnableAlarmActions($targetHost.ExtensionData.MoRef,$Enabled)
}
