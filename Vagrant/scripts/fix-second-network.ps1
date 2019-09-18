# Source: https://github.com/StefanScherer/adfs2
param ([String] $ip, [String] $dns)

#if (! (Test-Path 'C:\Program Files\VMware\VMware Tools')) {
#  Write-Host "Nothing to do for other providers than VMware."
#  exit 0
#}

Write-Host "$('[{0:HH:mm}]' -f (Get-Date))"
Write-Host "Setting IP address and DNS information for the Ethernet1 interface"
Write-Host "If this step times out, it's because vagrant is connecting to the VM on the wrong interface"
Write-Host "See https://github.com/clong/DetectionLab/issues/114 for more information"

$subnet = $ip -replace "\.\d+$", ""

$OSVersion = (get-itemproperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName).ProductName

if ($OSVersion -eq "Windows 7 Enterprise") {
  $name = (Get-WmiObject win32_NetworkAdapterConfiguration `
    | ? {$_.ipaddress -like "$subnet.*"} `
    | % {$_.GetRelated("win32_NetworkAdapter")} `
    | select NetConnectionID `
    | %{$_.NetConnectionID})
  if (!$name) {
    $name = (Get-WmiObject win32_NetworkAdapterConfiguration `
      | Where-Object {$_.ipaddress -like "169.254.*"} `
      | % {$_.GetRelated("win32_NetworkAdapter")} `
      | select NetConnectionID |%{$_.NetConnectionID})
  }
} else {
  $address = (Get-NetIPAddress -AddressFamily IPv4 `
     | Where-Object -FilterScript { ($_.IPAddress).StartsWith($subnet) } `
     ).IPAddress
  $name = (Get-NetIPAddress -AddressFamily IPv4 `
     | Where-Object -FilterScript { ($_.IPAddress).StartsWith($subnet) } `
     ).InterfaceAlias
  if (!$name) {
    $name = (Get-NetIPAddress -AddressFamily IPv4 `
       | Where-Object -FilterScript { ($_.IPAddress).StartsWith("169.254.") } `
       ).InterfaceAlias
  }
}

if ($ip -ne $address) {
  if ($name) {
    Write-Host "Set IP address to $ip, gateway to $subnet.222, and metric of 2 for interface $name"
    & netsh.exe int ip set address "$name" static $ip 255.255.255.0 "$subnet.222"
    & netsh.exe int ip set interface "$name" metric=1
  } else {
    Write-Error "Could not find a interface with subnet $subnet.xx"
  }
} else {
  Write-Host "IP Address set correctly. Change unnecessary."
}

if ($name -and $dns) {
  Write-Host "Set DNS server address to $dns of interface $name"
  & netsh.exe interface ipv4 add dnsserver "$name" address=$dns index=1
}