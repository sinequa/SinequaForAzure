#Install-Module PSWindowsUpdate -Force
#Get-WindowsUpdate -IgnoreReboot
Install-WindowsUpdate -AcceptAll -Install -IgnoreReboot

$reboot = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing"  -Name "RebootPending" -ErrorAction Ignore
if (-not $reboot) {
    $reboot = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update'  -Name 'RebootRequired' -ErrorAction Ignore
}
if (-not $reboot) {
    $res = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction Ignore
    if ($res -and $res.PendingFileRenameOperations) {
        $reboot = "PendingFileRenameOperations"
        $res.PendingFileRenameOperations
    }
}
if ($reboot) {
    Write-Host "Reboot required"
}