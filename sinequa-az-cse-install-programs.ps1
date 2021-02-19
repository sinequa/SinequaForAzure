
param (
    [Parameter(HelpMessage = "BGInfo File Url")]
    [string]    $bgFileUrl    
)

Set-StrictMode -Version latest;
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

# Remove escaping character "xxxx" used for Invoke-AzVMRunCommand parameter limitations
if ($bgFileUrl -and $bgFileUrl.length -gt 1 -and $bgFileUrl[0] -eq """" -and $bgFileUrl[$bgFileUrl.length-1] -eq """") { $bgFileUrl = $bgFileUrl -replace ".$" -replace "^." }


Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
#Windows Update by PowerShell    
Install-Module PSWindowsUpdate -Force

#Azure Storage
Install-Module Az.Storage -Force

#Instal IIS
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer
Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures
Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpErrors
Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpRedirect
Enable-WindowsOptionalFeature -Online -FeatureName IIS-ApplicationDevelopment
Enable-WindowsOptionalFeature -Online -FeatureName IIS-HealthAndDiagnostics
Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpLogging
Enable-WindowsOptionalFeature -Online -FeatureName IIS-LoggingLibraries
Enable-WindowsOptionalFeature -Online -FeatureName IIS-RequestMonitor
Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpTracing
Enable-WindowsOptionalFeature -Online -FeatureName IIS-Security
Enable-WindowsOptionalFeature -Online -FeatureName IIS-RequestFiltering
Enable-WindowsOptionalFeature -Online -FeatureName IIS-Performance
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerManagementTools
Enable-WindowsOptionalFeature -Online -FeatureName IIS-Metabase -All
Enable-WindowsOptionalFeature -Online -FeatureName IIS-ManagementConsole
Enable-WindowsOptionalFeature -Online -FeatureName IIS-BasicAuthentication
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WindowsAuthentication
Enable-WindowsOptionalFeature -Online -FeatureName IIS-StaticContent
Enable-WindowsOptionalFeature -Online -FeatureName IIS-DefaultDocument
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebSockets
Enable-WindowsOptionalFeature -Online -FeatureName IIS-ApplicationInit
Enable-WindowsOptionalFeature -Online -FeatureName IIS-ISAPIExtensions
Enable-WindowsOptionalFeature -Online -FeatureName IIS-ISAPIFilter
Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpCompressionStatic
Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASPNET45 -All

# Add inbound Firewall Rules for Sinequa
netsh advfirewall firewall add rule name= "Sinequa" dir=in action=allow protocol=TCP localport=10300-10500

#Go to Temp Drive
$tempDrive = "D:\"
Set-Location -Path $tempDrive

# Install Custom BGInfo
if ($bgFileUrl.Length -gt 0)
{
    Write-Output "Download $bgFileUrl"
    $bgFile = "$tempDrive\config.bgi"
    Invoke-WebRequest $bgFileUrl -OutFile $bgFile
    Move-Item -Path $bgFile -Destination "C:\Packages\Plugins\Microsoft.Compute.BGInfo\2.1" -Force
}

#Install .NET 4.7.2 (Sinequa Prerequisite)
<#
if ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Release -lt 461808) {
    Invoke-WebRequest "https://go.microsoft.com/fwlink/?LinkID=863265" -OutFile "$tempDrive\net472.exe"
    Start-Process -filepath "net472.exe" -ArgumentList "/q /norestart" -Wait -PassThru    
}
#>

# Winget
<#Invoke-WebRequest "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile "$tempDrive\Microsoft.VCLibs.x64.14.00.Desktop.appx"
$localPackage = "$tempDrive\Microsoft.VCLibs.x64.14.00.Desktop.appx"
DISM.EXE /Online /Add-ProvisionedAppxPackage /PackagePath:$localPackage /SkipLicense
Invoke-WebRequest "https://github.com/microsoft/winget-cli/releases/download/v-0.2.10191-preview/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.appxbundle" -OutFile "$tempDrive\winget.appxbundle"
$localPackage = "$tempDrive\winget.appxbundle"
DISM.EXE /Online /Add-ProvisionedAppxPackage /PackagePath:$localPackage /SkipLicense
#>

#Install C++ Resdistribuable (Sinequa Prerequisite)
#& winget install --silent -e --id Microsoft.VC++2015-2019Redist-x64
Invoke-WebRequest "https://aka.ms/vs/16/release/vc_redist.x64.exe" -OutFile "$tempDrive\vc_redist.x64.exe"
Start-Process -filepath "vc_redist.x64.exe" -ArgumentList "/install /passive /norestart" -Wait -PassThru

#Install 7zip
#& winget install --silent --id 7zip.7zip
Invoke-WebRequest "https://www.7-zip.org/a/7z1900-x64.exe" -OutFile "$tempDrive\7zsetup.exe"
Start-Process -filepath "7zsetup.exe" -ArgumentList "/S" -Wait -PassThru

########Install Optional programs

# Windows Terminal
#& winget install --silent -e --id Microsoft.WindowsTerminal


# Telnet Client
Install-WindowsFeature "telnet-client"

# Google Chrome
#& winget install --silent -e --id Google.Chrome
Invoke-WebRequest "http://dl.google.com/chrome/install/375.126/chrome_installer.exe" -OutFile "$tempDrive\chrome_installer.exe"
Start-Process -FilePath "chrome_installer.exe" -Args "/silent /install" -Verb RunAs -Wait

# NotePadd++
#& winget install --silent notepad++
Invoke-WebRequest "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v7.9/npp.7.9.Installer.exe" -OutFile "$tempDrive\npp.7.9.Installer.exe"
Start-Process -FilePath "npp.7.9.Installer.exe" -Args "/S" -Wait -PassThru

#Visual Code
#& winget install --silent -e --id Microsoft.VisualStudioCode
Invoke-WebRequest "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64" -OutFile "$tempDrive\VSCodeSetup.exe"
Start-Process -FilePath "VSCodeSetup.exe" -Args "/VERYSILENT /NORESTART /MERGETASKS=!runcode" -Wait -PassThru
