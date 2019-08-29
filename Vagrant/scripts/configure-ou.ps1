# Purpose: Sets up the Server and Workstations OUs

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Checking AD services status..."
$svcs = "adws","dns","kdc","netlogon"
Get-Service -name $svcs -ComputerName localhost | Select Machinename,Name,Status

# Hardcoding DC hostname in hosts file
Add-Content "c:\windows\system32\drivers\etc\hosts" "        172.16.163.211    dc.windomain.local"

# Force DNS resolution of the domain
ping /n 1 dc.windomain.local
ping /n 1 windomain.local

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Creating Server and Workstation OUs..."
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Creating Servers OU..."

$stoploop = $false
$retrycount = 0

# Disabling shell provisioners made configuring OUs fail after reload b/c policy wasn't fully installed
# Appears to take approximately 5 minutes
# https://www.thomasmaurer.ch/wp-content/uploads/2010/07/Screen-shot-2010-07-23-at-17.08.09.png  <= script from here
do {
    try {
        if (!([ADSI]::Exists("LDAP://OU=Servers,DC=windomain,DC=local")))
        {
            Write-Host "Creating Servers OU..."
            New-ADOrganizationalUnit -Name "Servers" -Server "dc.windomain.local"
        }
        else
        {
            Write-Host "Servers OU already exists. Moving On."
        }
        if (!([ADSI]::Exists("LDAP://OU=Workstations,DC=windomain,DC=local")))
        {
            Write-Host "Creating Workstations OU"
            New-ADOrganizationalUnit -Name "Workstations" -Server "dc.windomain.local"
        }
        else
        {
            Write-Host "Workstations OU already exists. Moving On."
        }
        $stoploop = $true
    }
    catch {
        if ($retrycount -gt 10) {
            Write-Host "Could not create OUs after 10 retries"
            $stoploop = $true
        }
        else {
            Write-Host "Could not create OUs. Retrying in 60 seconds."
            Start-Sleep -Seconds 60
            $retrycount = $retrycount + 1
        }
    }
} while ($stoploop -eq $false)

# Sysprep breaks auto-login. Let's restore it here:
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoAdminLogon -Value 1
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultUserName -Value "vagrant"
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultPassword -Value "vagrant"
