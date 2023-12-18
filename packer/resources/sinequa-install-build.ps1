<#
.SYNOPSIS
	Install a Sinequa Node
.DESCRIPTION
#>

param (
    [Parameter(HelpMessage="Build Download Url")]
	[string]	$downloadUrl, # eg "https://download.sinequa.com/api/filedownload?type=release&version=$version&file=sinequa.11.zip"

    [Parameter(HelpMessage="Build Download Token")]
	[string]	$downloadToken
)


# ERROR REPORTING ALL 
Set-StrictMode -Version latest;
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'
$StartTime = Get-Date

# Remove WARNING: breaking changes...
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

# Functions
function WriteLog ($message) {
    <#
    .SYNOPSIS
        Write a Log Message with Timestamp
    .PARAMETER message
        Message to log in console
    #>
    $date = (Get-Date).toString("yyyy-MM-dd hh:mm:ss") 
    Write-Output "$date $message"
}


# Variables
$tempDrive = "D:\"
$destinationFolder = "C:\"
$sinequaFolder = Join-Path $destinationFolder "sinequa"
$versionFile = Join-Path $sinequaFolder "version.txt"
$zipFile = "$tempDrive\sinequa.zip"
$serviceName = "sinequa.service"
$cloudInitServiceName = "sinequa.cloudinit.service"

# Check if downloadUrl is set
if (-not($downloadUrl)) {
	WriteLog "'downloadUrl' parameter is missing";
	Exit 0
}


# Set Sinequa Azure OS Environment Variables
WriteLog "Set Sinequa Azure OS Environment Variables";
[System.Environment]::SetEnvironmentVariable('SINEQUA_TEMP', 'd:\sinequa\temp',[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SINEQUA_CLOUD', 'Azure',[System.EnvironmentVariableTarget]::Machine)

# For Debugging Sinequa init - Folder must exist
[System.Environment]::SetEnvironmentVariable('SINEQUA_LOG_INIT', 'Path=d:\;Level=10000',[System.EnvironmentVariableTarget]::Machine)

# Add inbound Firewall Rules for Sinequa
WriteLog "Add Sinequa Rule in Firewall"
Get-NetFirewallRule -Name "SinequaServers" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -Name "SinequaServers" -DisplayName "Sinequa Server Ports" -Group "Sinequa" -Profile Any -Direction Inbound -Enabled True -Protocol TCP -LocalPort 10300-10500

# Exclude $sinequaFolder from Windows Defender
WriteLog "Update Windows Defender Exclusion";
Add-MpPreference -ExclusionPath $sinequaFolder
Add-MpPreference -ExclusionPath "F:\sinequa"

# Test if Sinequa is already installed
WriteLog "Sinequa will be installed on $destinationFolder";
if ((Test-Path $sinequaFolder) -and (Test-Path $versionFile)) {
	$currentVersion = Get-Content $versionFile;
	WriteLog "Sinequa is already installed: $currentVersion";
	Exit 0
}

# Download the Sinequa Distribution
WriteLog "Download from $downloadUrl to $zipFile";
$ProgressPreference = 'SilentlyContinue'
$downloadHeader = @{"Accept"="application/octet-stream"}
if ($downloadToken) {
    $downloadHeader = @{"Accept"="application/octet-stream"; "Authorization"="Bearer $downloadToken"}
}
$res = Invoke-WebRequest $downloadUrl -Method Get -Headers $downloadHeader -OutFile $zipFile 
$res
if (-not (Test-Path $zipFile)) {
	WriteLog "File not downloaded.";
	Exit 0
}

# Unzip Package
WriteLog "Unzip package" ;
& "C:\Program Files\7-Zip\7z.exe" x $zipFile "-o$destinationFolder"
$currentVersion = Get-Content $versionFile;
WriteLog "Unzip of $currentVersion binaries are done"

# Clean Old SBA v1 Stuffs (can be removed)
if (Test-Path "$sinequaFolder\assets\static\static_resources_sba1.zxb") {
    WriteLog "Remove SBA v1 resources"
    Remove-Item "$sinequaFolder\assets\static\static_resources_sba1.zxb" -Force    
}

# Install the Sinequa CloudInit
WriteLog "Install $cloudInitServiceName service"
$start = "delayed-auto"
& "sc.exe" "create" $cloudInitServiceName "start=$start" "binPath=""$sinequaFolder\bin\sinequa.cloudinit.exe """ "DisplayName=""$cloudInitServiceName"""

# Install the Sinequa service on demand. Sinequa.cloudInit will start it the firt time, and change it to auto
WriteLog "Install $serviceName service"
#$start = "delayed-auto"
$start = "demand"
& "sc.exe" "create" $serviceName "obj=NT Authority\NetworkService" "start=$start" "binPath=""$sinequaFolder\bin\sinequa.service.exe""" "DisplayName=""$serviceName"""

$EndTime = Get-Date
WriteLog "Script execution time: $($EndTime - $StartTime)"