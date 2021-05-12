

#Start Services
Write-Host "Start sinequa.service"
Set-Service -Name sinequa.service -StartupType Automatic
Start-Service -Name sinequa.service
Write-Host "Start w3svc"
Set-Service -Name w3svc -StartupType Automatic
Start-Service -Name w3svc

