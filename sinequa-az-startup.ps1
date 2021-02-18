#Find RAW disks and format them
[array]$disks = Get-Disk | where-object PartitionStyle -eq "RAW" 
if ($disks)
{
    foreach ($disk in $disks) {
        Write-Host "Initialize disk: $($disk.Number)"
        $null = Initialize-Disk -Number $disk.Number -PartitionStyle MBR -confirm:$false  
        $null = New-Partition -DiskNumber $disk.Number -UseMaximumSize -IsActive -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data Disk" -confirm:$False  
        $null = Set-Partition -DiskNumber $disk.Number -PartitionNumber 1
    }    
}

$sinequaPath = "c:\sinequa"
#IF F: exists, then SINEQUA_PATH is F:
if(Test-Path -Path "F:\") {
    $sinequaPath = "F:\sinequa"
    Write-Host "Use $sinequaPath as SINEQUA_PATH"
    [System.Environment]::SetEnvironmentVariable('SINEQUA_PATH', $sinequaPath ,[System.EnvironmentVariableTarget]::Machine)
}

# Create folder (for setting rights later)
if(-Not (Test-Path -Path $sinequaPath))
{
    Write-Host "Create $sinequaPath folder"
    New-Item -ItemType "directory" -Path $sinequaPath
}

#Add IIS_IUSRS privileges
if (Test-Path -Path $sinequaPath) {
    Write-Host "Add FullControl on $sinequaPath for BUILTIN\IIS_IUSRS"
    # Get the ACL for an existing folder
    $existingAcl = Get-Acl -Path $sinequaPath
    # Set the permissions that you want to apply to the folder
    $permissions = "BUILTIN\IIS_IUSRS", 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
    # Create a new FileSystemAccessRule object
    $rule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $permissions
    # Modify the existing ACL to include the new rule
    $existingAcl.AddAccessRule($rule)
    # Apply the modified access rule to the folder
    $existingAcl | Set-Acl -Path $sinequaPath
}

#Get Azure CustomData and use it for sinequa.startup.xml
if(Test-Path -Path "C:\AzureData\CustomData.bin") { 
    Write-Host "Create $sinequaPath\sinequa.startup.xml from Azure CustomData"
    $customData = [IO.File]::ReadAllText("C:\AzureData\CustomData.bin")
    $customData = $customData.Trim();
    if (($customData.Length % 4 -eq 0) -and $customData  -match "^[a-zA-Z0-9\+/]*={0,3}$") 
    {
        $customData= [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($customData))
    }
    Set-Content -Path "$sinequaPath\sinequa.startup.xml" -Value $customData
}


#Start Services
Write-Host "Start sinequa.service"
Set-Service -Name sinequa.service -StartupType Automatic
Start-Service -Name sinequa.service
Write-Host "Start w3svc"
Set-Service -Name w3svc -StartupType Automatic
Start-Service -Name w3svc

