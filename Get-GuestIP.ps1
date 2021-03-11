$vCenterServers = "ukh-vc1.kuha.kumed.com"
$DHCPServer = "ukh-dhcp01.kuha.kumed.com"
$VMExclusionFilter = "Guest Introspection|McAfee Move AV"

If (-not $myCredential) {$myCredential = Get-Credential}

Connect-VIServer -Server $vCenterServers -AllLinked:$true -Credential $myCredential

Write-Output "Gathering VMs..."
$allVMs = Get-VM * |  Where-Object {$_.Name -notmatch $VMExclusionFilter}

Write-Host "Gathering VM IPs..."
$allVMs = $allVMs | Get-VMGuest | Select-Object VM, IPAddress # -First 50 

$outputTable = @()

foreach ($vm in $allVMs) {
    ForEach ($IP in $vm.IPAddress) {
        If ($IP -match "\.") {
            $IP
            $myLease = $null
            $myLease = Get-DhcpServerv4Lease -ComputerName $DHCPServer -IPAddress $IP
            $myDNSName = Resolve-DnsName -NoHostsFile $IP
            If ($myLease.AddressState -match "Reservation") {
                ## YAY, we're reserved
            } else {
                $outputTable += $vm | Select-Object VM, @{ Name = 'IPAddress'; Expression = {$IP}},@{ Name = 'DNSName'; Expression = {$myDNSName.NameHost}},@{ Name = 'AddressState'; Expression = {$myLease.AddressState}}
            }
        }
    }
}