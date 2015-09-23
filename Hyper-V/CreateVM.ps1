#
# We should turn this into a module...
#
param (
    [parameter(Mandatory)][string[]] $Namelist,
#    [string] $Template = 'ws2016tp3_sysprepped.vhdx',
    [string] $Template = 'WS2K12R2SP1_20150702_sysprepped.vhdx',
    [string] $Answerfile = 'Unattend_templ.xml',
    [string] $Hypervroot = 'C:\_Hyper-V',
    [string] $VMSwitch = 'Internal',
    [switch] $Start = $false
)


$answerfilepath = $hypervroot + "\" + $answerfile
if (!(Test-Path $answerfilepath)) { Write-Error "$answerfilepath does not exist" ; Exit }
$templatepath = $hypervroot + '\Virtual Hard Disks\' + $template
if (!(Test-Path $templatepath)) { Write-Error "$templatepath does not exist" ; Exit }

function CreateUnattendXml()
{
    Param(
        [string]$templatePath,
        [string]$machineName,
        [string]$destinationPath
    )
    
    [xml] $config = [xml] (Get-Content $templatePath)

    $node = $config.unattend.settings  | ? { $_.pass -eq "specialize" }
    $snode = $node.component | ? {$_.name -eq "Microsoft-Windows-Shell-Setup"}
    $snode.ComputerName = $machineName

    if (Test-Path $destinationPath) { Remove-Item $destinationPath -Force }

    $config.Save($destinationPath)
}

foreach ($vmname in $Namelist) {
    "Creating a VM ($vmname) using '$Template'"

    $vhdpath = $Hypervroot + '\Virtual Hard Disks\' + $vmname + '.vhdx'
    if (Test-Path $vhdpath) {
        Write-Warning "$vhdpath already exists - will not create..."
    } else {
        "  Creating VHD using '$Answerfile'..."
        $vhd = New-VHD -Path $vhdpath -ParentPath $templatepath
        $mp = Mount-VHD -Path $vhdpath -NoDriveLetter -Passthru
        $tmppathname = [DateTime]::Now.ToFileTime()
        $tmppath = New-Item -Path "$Hypervroot\Virtual Hard Disks\$tmppathname" -ItemType Directory
        $setuppath = "$tmppath\Windows\Setup\Scripts"
        $part = ($mp | Get-Disk | Get-Partition | Sort-Object Size)[-1] #Get biggest partition
        $part | Add-PartitionAccessPath -AccessPath $tmppath.FullName
        CreateUnattendXml -templatePath $answerfilepath -machineName $vmname -destinationPath "$tmppath\Unattend.xml"
        if (!(Test-Path $setuppath)) { $null = New-Item $setuppath -ItemType Directory }
        "del C:\Unattend.xml" | Out-File "$setuppath\SetupComplete.cmd" -Encoding ascii
        $part | Remove-PartitionAccessPath -AccessPath $tmppath.FullName
        Dismount-VHD -Path $vhdpath
        Remove-Item -Path "$Hypervroot\Virtual Hard Disks\$tmppathname"
    }

    $vm = Get-VM $vmname -ErrorAction SilentlyContinue
    if ($vm -ne $empty) {
        Write-Warning "$vmname already exists - will not create..."
    } else {
        "  Create vm with the '$VMSwitch' switch..."
        $vm = New-VM -Name $vmname -MemoryStartupBytes 512MB -Generation 2 -SwitchName $VMSwitch -VHDPath $vhdpath
    }
    #Enable "Guest Services" so that we can copy files to the vm without network...
    $vm | Enable-VMIntegrationService -Name "Guest Service Interface"
    $vm | Set-VM -MemoryMinimumBytes 64MB -MemoryMaximumBytes 2GB
    if ($Start) {
	"  Starting the VM..."
	$vm | Start-VM
    }
}
