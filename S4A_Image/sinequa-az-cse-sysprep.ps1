
 # Remove any left over CustomScriptExtension files.
 Write-Host "Clean scripts: CustomScriptExtension"
 $cseDir = 'C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\'
 if (Test-Path -Path $cseDir)
 {
     Remove-Item -Recurse -Force $cseDir -ErrorAction SilentlyContinue | Out-Null
 }
 Write-Host "Clean scripts: RunCommandWindows"
 $cseDir = 'C:\Packages\Plugins\Microsoft.CPlat.Core.RunCommandWindows\'
 if (Test-Path -Path $cseDir)
 {
     Remove-Item -Recurse -Force $cseDir -ErrorAction SilentlyContinue | Out-Null
 }

Write-Host "Sysprep"
& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quit /mode:vm

Write-Host "Waiting for the image state"
while($true) {
    $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select-Object ImageState;
    if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') {
        Write-Host $imageState.ImageState;
        Start-Sleep -s 10  
    } else {
        Write-Host $imageState.ImageState;
        break
    }
}
Write-Host "Ready"
# shutdown /s /t 1 /f 