
param (
    [Parameter(HelpMessage="Type of cloud")]
	[string]	$cloud = "" # azure|aws|gcp
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

WriteLog "Install Nuget"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

# Extend Disk C is os-disk-size is greater than the original osdisk image
WriteLog "Extend OS Disk Size"
Set-Content -Path ./diskpart.txt -Value "list disk`nlist volume`nselect volume C`nextend"
diskpart.exe -s diskpart.txt

# Go to Install Directory
$installDir = "c:\install"
if (-not(Test-Path $installDir)) { New-Item -Path $installDir -ItemType Directory -Force }
Set-Location -Path $installDir


# Install Custom BGInfo (This file has to be accessible for downloading - e.g. a blob Storage)
$srcBgFile = "$installDir\config.bgi"
if (Test-Path $srcBgFile -PathType leaf)
{
    $bgDir = "c:\bginfo"
    New-Item -Path $bgDir -ItemType Directory -Force

    #Install BGinfo
    WriteLog "Install BGinfo"
    Invoke-WebRequest "https://live.sysinternals.com/Bginfo.exe" -OutFile "$bgDir\Bginfo.exe"

    $bgFile = "$bgDir\config.bgi"
    Copy-Item -Path $srcBgFile -Destination $bgDir -Force 
   
    $bgInfoRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    $bgInfoRegKey = "BgInfo"
    $bgInfoRegType = "String"
    $bgInfoRegKeyValue = "$bgDir\Bginfo.exe $bgFile /timer:0 /nolicprompt"
    $regKeyExists = (Get-Item $bgInfoRegPath -EA Ignore).Property -contains $bgInfoRegkey

    ## Create BgInfo Registry Key to AutoStart
    If ($regKeyExists -eq $False) { New-ItemProperty -Path $bgInfoRegPath -Name $bgInfoRegkey -PropertyType $bgInfoRegType -Value $bgInfoRegkeyValue } 
}



# Install C++ Resdistribuable (Sinequa Prerequisite)
WriteLog "Install vc_redist"
Invoke-WebRequest "https://aka.ms/vs/16/release/vc_redist.x64.exe" -OutFile "$installDir\vc_redist.x64.exe"
Start-Process -filepath "vc_redist.x64.exe" -ArgumentList "/install /passive /norestart" -Wait -PassThru

# Install 7zip
WriteLog "Install 7zip"
Invoke-WebRequest "https://www.7-zip.org/a/7z2107-x64.exe" -OutFile "$installDir\7zsetup.exe"
Start-Process -filepath "7zsetup.exe" -ArgumentList "/S" -Wait -PassThru

# Setting the NLA information to Disabled
(Get-WmiObject -class "Win32_TSGeneralSetting" -Namespace root\cimv2\terminalservices -ComputerName $env:COMPUTERNAME -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0)

# Install NVIDIA GPU Driver
# it requires to run this script on a VM with GPU, otherwise the driver is not installed in the image
$nvidiaDriverUrl = "https://us.download.nvidia.com/tesla/537.70/537.70-data-center-tesla-desktop-winserver-2019-2022-dch-international.exe"
if ($cloud.ToLower() -eq "aws") {
    # https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/install-nvidia-driver.html
    $nvidiaDriverUrl = "https://ec2-windows-nvidia-drivers.s3.us-east-1.amazonaws.com/grid-16.2/537.70_grid_win10_win11_server2019_server2022_dch_64bit_international_aws_swl.exe"
} elseif ($cloud.ToLower() -eq "gcp") {
    # https://cloud.google.com/compute/docs/gpus/grid-drivers-table?hl=fr#windows_drivers
    $nvidiaDriverUrl = "https://storage.googleapis.com/nvidia-drivers-us-public/GRID/vGPU16.4/538.33_grid_win10_win11_server2019_server2022_dch_64bit_international.exe"
} elseif ($cloud.ToLower() -eq "azure") {
    # https://learn.microsoft.com/en-us/azure/virtual-machines/windows/n-series-driver-setup
    $nvidiaDriverUrl = "https://download.microsoft.com/download/c/b/0/cb00d90e-5786-4882-89cd-75fb17fa787d/538.15_grid_win10_win11_server2019_server2022_dch_64bit_international_azure_swl.exe"
}
WriteLog "Download NVIDIA Driver: $nvidiaDriverUrl"
Invoke-WebRequest $nvidiaDriverUrl -OutFile "$installDir\nvidia-driver.exe"
& "C:\Program Files\7-Zip\7z.exe" x "nvidia-driver.exe" "-onvidia"

WriteLog "Install NVIDIA Driver"
Start-Process -FilePath "nvidia\setup.exe" -Args "-noreboot -noeula -clean -passive -nofinish -s" -Wait -PassThru
WriteLog "Check Install of NVIDIA Driver"
if ( Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue) 
{
    & "nvidia-smi.exe"
} else {
    WriteLog "Driver not installed. Please check that the current machine has GPU."
}


########Install Optional programs

# Google Chrome (can be removed)
WriteLog "Install Google Chrome"
Invoke-WebRequest "http://dl.google.com/chrome/install/375.126/chrome_installer.exe" -OutFile "$installDir\chrome_installer.exe"
Start-Process -FilePath "chrome_installer.exe" -Args "/silent /install" -Verb RunAs -Wait


# Visual Code (can be removed)
WriteLog "Install Visual Code"
Invoke-WebRequest "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64" -OutFile "$installDir\VSCodeSetup.exe"
Start-Process -FilePath "VSCodeSetup.exe" -Args "/VERYSILENT /NORESTART /MERGETASKS=!runcode" -Wait -PassThru

# GIT Client (can be removed)
WriteLog "Install Git Client"
Invoke-WebRequest "https://github.com/git-for-windows/git/releases/download/v2.41.0.windows.1/Git-2.41.0-64-bit.exe" -OutFile "$installDir\git.exe"
Start-Process -FilePath "git.exe" -Args "/VERYSILENT /NORESTART /MERGETASKS=!runcode" -Wait -PassThru

<#
# Visual Studio (can be removed)
WriteLog "Install Visual Studio 2022"
Invoke-WebRequest "https://aka.ms/vs/17/release/vs_professional.exe" -OutFile "$installDir\vs_Professional.exe"
Start-Process -FilePath "vs_Professional.exe" -Args "--add Microsoft.VisualStudio.Workload.CoreEditor --add Microsoft.VisualStudio.Workload.Azure --add Microsoft.VisualStudio.Workload.NetWeb --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended --passive --wait" -Wait -PassThru
#>