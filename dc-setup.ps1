### VARIABLES ###
# Define the Computer Name
$computerName = "DC480-01"

# Define the IPv4 Addressing
$IPv4Address = "10.0.17.4"
$IPv4Prefix = "24"
$IPv4GW = "10.0.17.2"
$IPv4DNS = "10.0.17.2"

# DNS info
$NetworkID = "10.0.17.0/24"

###
if($args[0] -eq $null){
	Write-Host "0 = change hostname & set IP. 1 = Install AD Domain Services. 2 = Install forest, DNS Serv., Set up DNS, enable RDP, install and conf DHCP, create admin user."
} elseif ($args[0] -eq 0){
	# Get the Network Adapter's Prefix
	$ipIF = (Get-NetAdapter).ifIndex
	
	# Add IPv4 Address, Gateway, and DNS
	New-NetIPAddress -InterfaceIndex $ipIF -IPAddress $IPv4Address -PrefixLength $IPv4Prefix -DefaultGateway $IPv4GW
	Set-DNSClientServerAddress –interfaceIndex $ipIF –ServerAddresses $IPv4DNS
	
	# Rename the Computer, and Restart
	Rename-Computer -NewName $computerName -force
	Restart-Computer
} elseif($args[0] -eq 1){
	Add-WindowsFeature AD-Domain-Services -IncludeAllSubFeature
} elseif($args[0] -eq 2){
	Install-WindowsFeature -Name DNS -IncludeManagementTools
	Install-ADDSForest -DomainName "campbell.local" -InstallDNS
	
	# Set up the reverse look up zone
	Add-DnsServerPrimaryZone -NetworkId $NetworkID -ReplicationScope "Domain"
	
	## VCENTER ##
	Add-DnsServerResourceRecordA -Name "vcenter.campbell.local" -ZoneName "campbell.local" -AllowUpdateAny -IPv4Address "10.0.17.3" 
	Add-DnsServerResourceRecordPtr -Name "vcenter" -ZoneName "17.0.10.in-addr.arpa" -AllowUpdateAny -AgeRecord -PtrDomainName "campbell.local"
	
	## FW ##
	Add-DnsServerResourceRecordA -Name "480-fw" -ZoneName "campbell.local" -AllowUpdateAny -IPv4Address "10.0.17.2" 
	Add-DnsServerResourceRecordPtr -Name "480-fw" -ZoneName "17.0.10.in-addr.arpa" -AllowUpdateAny -AgeRecord -PtrDomainName "campbell.local"
	
	## XUBUNTU ##
	Add-DnsServerResourceRecordA -Name "xubuntu-wan" -ZoneName "campbell.local" -AllowUpdateAny -IPv4Address "10.0.17.100" 
	Add-DnsServerResourceRecordPtr -Name "xubuntu-wan" -ZoneName "17.0.10.in-addr.arpa" -AllowUpdateAny -AgeRecord -PtrDomainName "campbell.local"
	
	## DC01 ##
	Add-DnsServerResourceRecordA -Name "dc1" -ZoneName "campbell.local" -AllowUpdateAny -IPv4Address "10.0.17.4" 
	Add-DnsServerResourceRecordPtr -Name "dc1" -ZoneName "17.0.10.in-addr.arpa" -AllowUpdateAny -AgeRecord -PtrDomainName "campbell.local"
	
	# Enable RDP

	Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0

	Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

	## DHCP ##

	Install-WindowsFeature DHCP -IncludeManagementTools

	netsh dhcp add securitygroups

	Add-DHCPServerv4Scope -Name “campbell.local” -StartRange 10.0.17.101 -EndRange 10.0.17.150 -SubnetMask 255.255.255.0 -State Active

	Set-DHCPServerv4OptionValue -ScopeID 10.0.17.0 -DnsDomain campbell.local -DnsServer 10.0.17.4 -Router 10.0.17.2

	Add-DhcpServerInDC -DnsName campbell.local -IpAddress 10.0.17.4

	Restart-service dhcpserver

	## Creating a named admin user ##

	Import-Module ActiveDirectory

	$pw = Read-Host -Prompt 'Enter a Password for this user' -AsSecureString 
	New-ADUser -Name miles-adm -AccountPassword $pw -Passwordneverexpires $true -Enabled $true
	Add-ADGroupMember -Identity "Domain Admins" -Members miles-adm
}