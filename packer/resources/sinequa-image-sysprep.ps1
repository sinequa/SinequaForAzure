function WriteLog ($message) {
    <#
    .SYNOPSIS
        Write a Log Message with Timestamp
    .PARAMETER message
        Message to log in console
    #>
    $date = (Get-Date).toString("yyyy-MM-dd hh:mm:ss") 
    Write-Host "$date $message"
}


WriteLog "Sysprep"
& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit /mode:vm

WriteLog "Waiting for the image state"
while($true) {
    $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select-Object ImageState;
    if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') {
        WriteLog $imageState.ImageState;
        Start-Sleep -s 10  
    } else {
        WriteLog $imageState.ImageState;
        break
    }
}
Write-Host "Ready"
#Write-Host "Shutting down"
#shutdown /s /t 1 /f 