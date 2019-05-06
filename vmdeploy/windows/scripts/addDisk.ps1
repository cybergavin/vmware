Get-disk | ?{$_.PartitionStyle -eq "RAW" -and $_.Location -eq "SCSI0"} | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -DriveLetter K -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "BACKUP" -Confirm:$False
Get-disk | ?{$_.PartitionStyle -eq "RAW" -and $_.Location -eq "SCSI1"} | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -DriveLetter L -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "LOG" -Confirm:$False
Get-disk | ?{$_.PartitionStyle -eq "RAW" -and $_.Location -eq "SCSI2"} | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -DriveLetter S -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "DATA" -Confirm:$False
Get-disk | ?{$_.PartitionStyle -eq "RAW" -and $_.Location -eq "SCSI3"} | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -DriveLetter T -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "TEMP" -Confirm:$False
