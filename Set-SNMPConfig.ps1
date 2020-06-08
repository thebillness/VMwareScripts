param (
    [Parameter(Mandatory=$true)] [String[]] $ROCommunity = "public", # String array of Read-Only communities
    [Parameter(Mandatory=$true)] $VMHost, # VMHost(s) to be configured
    [String] $SysContact, # System Contact, typically an email address or name
    [String] $SysLocation # System Location
)

# For Each VMHost to be configured
foreach ($targetHost in $VMHost) {
  ## Invoke the ESXCLI object
  $esxcli = Get-EsxCli -VMHost $targetHost -V2
  ## Create the snmp arguments
  $arguments = $esxcli.system.snmp.set.CreateArgs()
  ## Enable the configuration
  $arguments.enable = $true
  ## Set communities
  $arguments.communities = $ROCommunity
  ## Set the port
  $arguments.port = 161
  ## Set the System Contact
  $arguments.syscontact = $SysContact
  ## Set the System Location
  $arguments.syslocation = $SysLocation
  ## Apply the configuration
  $esxcli.system.snmp.set.Invoke($arguments)

  ## Get the SNMP service
  $snmpd = Get-VMHostService -VMHost $vmhost | where {$_.Key -eq "snmpd"}
  ## Start SNMP service - if not configured properly it will fail
  $snmpd | Start-VMHostService
  ## Set the service to start at boot
  $snmpd | Set-VMHostService -Policy "On"

  ## Check to see if the firewall is configured
  $firewallRule = $targetHost | Get-VMHostFirewallException | Where-Object {$_.Name -eq "SNMP Server"}
  ### If the firewall exception is not enabled
  If (-not $firewallRule.Enabled) {
    ### Enable it
    $firewallRule | Set-VMHostFirewallException -Enabled
  }
}
 