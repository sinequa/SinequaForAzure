
param (
    [Parameter(HelpMessage = "BGInfo File Url")]
    [string]    $bgFileUrl    
)

Set-StrictMode -Version latest;
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'


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

# Remove escaping character "xxxx" used for Invoke-AzVMRunCommand parameter limitations
if ($bgFileUrl -and $bgFileUrl.length -gt 1 -and $bgFileUrl[0] -eq """" -and $bgFileUrl[$bgFileUrl.length-1] -eq """") { $bgFileUrl = $bgFileUrl -replace ".$" -replace "^." }

WriteLog "Install Nuget"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

#Windows Update by PowerShell    
WriteLog "Install Windows Updates PS Package"
Install-Module PSWindowsUpdate -Force

#Extend Disk C is os-disk-size is greater than the original osdisk image
WriteLog "Extend OS Disk Size"
Set-Content -Path ./diskpart.txt -Value "list disk`nlist volume`nselect volume C`nextend"
diskpart.exe -s diskpart.txt

#Azure Storage
WriteLog "Install Azure PS Package"
Install-Module Az.Storage -Force

#Go to Temp Drive
$tempDrive = "D:\"
Set-Location -Path $tempDrive

# Install Custom BGInfo (This file has to be accessible for downloading - e.g. a blob Storage)
if ($bgFileUrl.Length -gt 0)
{
    WriteLog "Download $bgFileUrl"
    $bgFile = "$tempDrive\config.bgi"
    Invoke-WebRequest $bgFileUrl -OutFile $bgFile
    $bgInfoDir = Get-ChildItem -Directory -Path "C:\Packages\Plugins\Microsoft.Compute.BGInfo"
    Copy-Item -Path $bgFile -Destination $bgInfoDir.FullName -Force
}

#Install C++ Resdistribuable (Sinequa Prerequisite)
WriteLog "Install vc_redist"
Invoke-WebRequest "https://aka.ms/vs/16/release/vc_redist.x64.exe" -OutFile "$tempDrive\vc_redist.x64.exe"
Start-Process -filepath "vc_redist.x64.exe" -ArgumentList "/install /passive /norestart" -Wait -PassThru

#Install 7zip
WriteLog "Install 7zip"
Invoke-WebRequest "https://www.7-zip.org/a/7z2107-x64.exe" -OutFile "$tempDrive\7zsetup.exe"
Start-Process -filepath "7zsetup.exe" -ArgumentList "/S" -Wait -PassThru

# Setting the NLA information to Disabled
(Get-WmiObject -class "Win32_TSGeneralSetting" -Namespace root\cimv2\terminalservices -ComputerName $env:COMPUTERNAME -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0)

# Install NVIDIA GPU Driver
WriteLog "Install NVIDIA Tesla Driver"
Invoke-WebRequest "https://download.microsoft.com/download/7/3/6/7361d1b9-08c8-4571-87aa-18cf671e71a0/512.78_grid_win10_win11_server2016_server2019_server2022_64bit_azure_swl.exe" -OutFile "$tempDrive\nvidia-driver.exe"
& "C:\Program Files\7-Zip\7z.exe" x "nvidia-driver.exe" "-onvidia"
Start-Process -FilePath "nvidia\setup.exe" -Args "-noreboot -noeula -clean -passive -nofinish" -Wait -PassThru


########Install Optional programs

# Google Chrome (can be removed)
WriteLog "Install Google Chrome"
Invoke-WebRequest "http://dl.google.com/chrome/install/375.126/chrome_installer.exe" -OutFile "$tempDrive\chrome_installer.exe"
Start-Process -FilePath "chrome_installer.exe" -Args "/silent /install" -Verb RunAs -Wait

# NotePad++ (can be removed)
WriteLog "Install Notepad++"
[xml]$npp = (New-Object System.Net.WebClient).DownloadString("https://notepad-plus-plus.org/update/getDownloadUrl.php")
Invoke-WebRequest $npp.GUP.Location -OutFile "$tempDrive\npp.Installer.exe"
Start-Process -FilePath "npp.Installer.exe" -Args "/S" -Wait -PassThru

# Visual Code (can be removed)
WriteLog "Install Visual Code"
Invoke-WebRequest "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64" -OutFile "$tempDrive\VSCodeSetup.exe"
Start-Process -FilePath "VSCodeSetup.exe" -Args "/VERYSILENT /NORESTART /MERGETASKS=!runcode" -Wait -PassThru

# GIT Client (can be removed)
WriteLog "Install Git Client"
Invoke-WebRequest "https://github.com/git-for-windows/git/releases/download/v2.30.2.windows.1/Git-2.30.2-64-bit.exe" -OutFile "$tempDrive\git.exe"
Start-Process -FilePath "git.exe" -Args "/VERYSILENT /NORESTART /MERGETASKS=!runcode" -Wait -PassThru

<#
# Visual Studio (can be removed)
WriteLog "Install Visual Studio 2022"
Invoke-WebRequest "https://aka.ms/vs/17/release/vs_professional.exe" -OutFile "$tempDrive\vs_Professional.exe"
Start-Process -FilePath "vs_Professional.exe" -Args "--add Microsoft.VisualStudio.Workload.CoreEditor --add Microsoft.VisualStudio.Workload.Azure --add Microsoft.VisualStudio.Workload.NetWeb --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended --passive --wait" -Wait -PassThru
#>