<#
.SYNOPSIS
	Install a Sinequa Node
.DESCRIPTION
#>

param (
	[Parameter(HelpMessage="Url of the package")]
	[string]	$fileUrl, # eg "http://.../sinequa.*.zip",

    [Parameter(HelpMessage="Url of the package")]
	[string]	$filePath # eg "C:\install\sinequa.*.zip"	

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
$sinequaScriptsFolder = Join-Path $sinequaFolder "scripts"
$versionFile = Join-Path $sinequaFolder "version.txt"
$zipFile = "$tempDrive\sinequa.zip"
if ($filePath) {$zipFile = $filePath}
$serviceName = "sinequa.service"
$cloudInitServiceName = "sinequa.cloudinit.service"

# Remove escaping character "xxxx" used for Invoke-AzVMRunCommand parameter limitations
if ($fileUrl -and $fileUrl.length -gt 1 -and $fileUrl[0] -eq """" -and $fileUrl[$fileUrl.length-1] -eq """") { $fileUrl = $fileUrl -replace ".$" -replace "^." }

	
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
WriteLog "Install Sinequa in $destinationFolder";
if ((Test-Path $sinequaFolder) -and (Test-Path $versionFile)) {
	$currentVersion = Get-Content $versionFile;
	WriteLog "Sinequa is already installed: $currentVersion";
	Exit 0
}

# Download the Sinequa Distribution
if ($fileUrl) {
    WriteLog "Download $($fileUrl)";
    Invoke-WebRequest $fileUrl -OutFile $zipFile
    if (-Not (Test-Path $sinequaScriptsFolder)) {
        New-Item $sinequaScriptsFolder -ItemType Directory
    }   
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
& "sc.exe" "create" $cloudInitServiceName "start=$start" "binPath=""$sinequaFolder\bin\sinequa.cloudinit.exe""" "DisplayName=""$cloudInitServiceName"""

# Install the Sinequa service on demand. Sinequa.cloudInit will start it the firt time, and change it to auto
WriteLog "Install $serviceName service"
#$start = "delayed-auto"
$start = "demand"
& "sc.exe" "create" $serviceName "obj=NT Authority\NetworkService" "start=$start" "binPath=""$sinequaFolder\bin\sinequa.service.exe""" "DisplayName=""$serviceName"""

$EndTime = Get-Date
WriteLog "Script execution time: $($EndTime - $StartTime)"