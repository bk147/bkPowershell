param (
    [parameter(Mandatory=$true)]
    [string[]]$VMList
)

foreach ($vmname in $VMList) {
    $vm = Get-VM $vmname -ErrorAction SilentlyContinue
    "Destroying $vmname..."
    if ($vm) {
        $disklist = $vm | Get-VMHardDiskDrive
        foreach ($disk in $disklist) {
            if (Test-Path $disk.Path) {
                "Removing '$($disk.Path)'..."
                $null = Remove-Item $disk.Path
            } else {
                Write-Warning "Disk '$($disk.Path)' already deleted..."
            }
        }
        $vm | Remove-VM -Force
    } else {
        Write-Warning "$vmname not found - ignoring..."
    }
}