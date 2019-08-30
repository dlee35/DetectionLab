# Purpose: Installs Winlogbeat into c:\ProgramData\Winlogbeat. Used to ship logs.

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing Elastic Winlogbeat..."

# Purpose: Downloads and unzips a copy of the specified version of Winlogbeat
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading Winlogbeat..."
# GitHub requires TLS 1.2 as of 2/27
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$winlogbeatDownloadUrl = "https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-6.8.2-windows-x86_64.zip"
$winlogbeatRepoPath = 'C:\Users\vagrant\AppData\Local\Temp\winlogbeat-6.8.2.zip'
$winlogbeatInstallPath = 'c:\ProgramData\winlogbeat-6.8.2-windows-x86_64\'
if (-not (Test-Path $winlogbeatRepoPath))
{
  Invoke-WebRequest -Uri "$winlogbeatDownloadUrl" -OutFile $winlogbeatRepoPath
  Expand-Archive -path "$winlogbeatRepoPath" -destinationpath 'c:\ProgramData\' -Force
  Set-Location -path $winlogbeatInstallPath
  Copy-Item -path 'c:\vagrant\resources\beats\wef-winlogbeat.yml' -Destination 'winlogbeat.yml'
  .\install-service-winlogbeat.ps1
  Start-Service winlogbeat
}
else
{
  Write-Host "Winlogbeat was already installed. Moving On."
}

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Winlogbeat installation complete!"
