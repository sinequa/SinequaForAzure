<#
.SYNOPSIS
	Install a Sinequa Node
.DESCRIPTION
#>

param (
	[Parameter(HelpMessage="Url of the package")]
	[string]	$fileUrl = "C:\install\sinequa.*.zip",
	
	[Parameter(HelpMessage="Url of the Azure Startup File")]
    [string]	$startupFileUrl = "C:\install\sinequa.*.zip"    

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
$startupFile = "$sinequaScriptsFolder\sinequa-az-startup.ps1"
$serviceName = "sinequa.service"

# Remove escaping character "xxxx" used for Invoke-AzVMRunCommand parameter limitations
if ($fileUrl -and $fileUrl.length -gt 1 -and $fileUrl[0] -eq """" -and $fileUrl[$fileUrl.length-1] -eq """") { $fileUrl = $fileUrl -replace ".$" -replace "^." }
if ($startupFileUrl -and $startupFileUrl.length -gt 1 -and $startupFileUrl[0] -eq """" -and $startupFileUrl[$startupFileUrl.length-1] -eq """") { $startupFileUrl = $startupFileUrl -replace ".$" -replace "^." }
	
# Set Sinequa Azure Env Vars
WriteLog "Set Sinequa Azure Env Vars";
[System.Environment]::SetEnvironmentVariable('SINEQUA_TEMP', 'd:\sinequa\temp',[System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('SINEQUA_CLOUD', 'Azure',[System.EnvironmentVariableTarget]::Machine)

# Exclude sinequaFolder from Windows Defender
WriteLog "Update Windows Defender Exclusion";
Add-MpPreference -ExclusionPath $sinequaFolder

# Test if installed
WriteLog "Install $zipFile in $destinationFolder";
if ((Test-Path $sinequaFolder) -and (Test-Path $versionFile)) {
	$currentVersion = Get-Content $versionFile;
	WriteLog "Sinequa is already installed: $currentVersion";
	Exit 0
}

# Download Files
WriteLog "Download $($fileUrl)";
Invoke-WebRequest $fileUrl -OutFile $zipFile
if (-Not (Test-Path $sinequaScriptsFolder)) {
    New-Item $sinequaScriptsFolder -ItemType Directory
}
WriteLog "Download $startupFileUrl";
Invoke-WebRequest $startupFileUrl -OutFile $startupFile

# Unzip Package
WriteLog "Unzip package" ;
& "C:\Program Files\7-Zip\7z.exe" x $zipFile "-o$destinationFolder"
$currentVersion = Get-Content $versionFile;
WriteLog "Unzip of $currentVersion binaries are done"

# Add IIS rigths
WriteLog "Add IIS rigths"
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS_IUSRS", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl = Get-ACL $sinequaFolder
$acl.AddAccessRule($accessRule)
Set-ACL -Path $sinequaFolder -ACLObject $acl

# Install service
WriteLog "Install $serviceName service"
$cmd = "sc.exe";
$start = "demand"
& $cmd "create" $serviceName "start=$start" "binPath=""$sinequaFolder\website\bin\sinequa.service.exe""" "DisplayName=sinequa.service"
 
# Install Website
WriteLog "Install Sinequa website";
Import-Module WebAdministration
Set-ItemProperty 'IIS:\Sites\Default Web Site\' -name physicalPath -value "$sinequaFolder\website"
C:\Windows\System32\inetsrv\appcmd.exe set config http://localhost -section:system.webServer/isapiFilters /+"[name='Sinequa',path='$sinequaFolder\website\bin\sinequa_filter.dll',enabled='True',enableCache='True']" /commit:apphost

# Disable Services
WriteLog "Disable Service for first Windows boot";
Set-Service -Name sinequa.service -StartupType Disabled
Set-Service -Name w3svc -StartupType Disabled

$EndTime = Get-Date
WriteLog "Script execution time: $($EndTime - $StartTime)"