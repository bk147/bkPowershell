param (
    [parameter(Mandatory)][string[]] $Namelist,
    [string] $isoPath = 'C:\_MDTBuildLab\Boot\MDTBuildLab_x64.iso',
    [string] $Hypervroot = 'C:\_Hyper-V',
    [string] $VMSwitch = 'Internal',
    [switch] $Start = $false
)


if (!(Test-Path $isoPath)) { Write-Error "$isoPath does not exist - exiting..." ; Exit }

foreach ($vmname in $Namelist) {
    "Creating a VM ($vmname) using '$isoPath'"

    $vhdpath = $Hypervroot + '\Virtual Hard Disks\' + $vmname + '.vhdx'
    if (Test-Path $vhdpath) {
        Write-Warning "$vhdpath already exists - will not create vm..."
    } else {
        $vm = Get-VM $vmname -ErrorAction SilentlyContinue
        if ($vm -ne $empty) {
            Write-Warning "$vmname already exists - will not create..."
        } else {
            "  Create vm with the '$VMSwitch' switch..."
            $vm = New-VM -Name $vmname -MemoryStartupBytes 1024MB -Generation 2 -SwitchName $VMSwitch -NewVHDPath $vhdpath -NewVHDSizeBytes 127GB
            $bootdev = $vm | Add-VMDVDDrive -Path $isoPath -Passthru
        }

        #Enable "Guest Services" so that we can copy files to the vm without network...
        $vm | Enable-VMIntegrationService -Name "Guest Service Interface"

        $vm | Set-VM -MemoryMinimumBytes 1024MB -MemoryMaximumBytes 2GB
        $vm | Set-VMFirmware -FirstBootDevice $bootdev

        if ($Start) {
	        "  Starting the VM..."
	        $vm | Start-VM
        }
    }
}
