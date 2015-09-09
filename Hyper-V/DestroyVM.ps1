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
            "Removing '$($disk.Path)'..."
            $null = Remove-Item $disk.Path
        }
        $vm | Remove-VM -Force
    } else {
        Write-Warning "$vmname not found - ignoring..."
    }
}