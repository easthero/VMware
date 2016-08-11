param(
	[string]$viserver=$(throw "Parameter missing: -viserver vcenterip"),
	[string]$username=$(throw "Parameter missing: -username username"),
	[string]$password=$(throw ":Parameter missing: -password vcenterpassword"),
	[string]$cluster,
	[string]$esxhost
)

if ( "$cluster" -eq "" -and "$esxhost" -eq "" ){
	write-host "集群名称cluster或ESXi主机名esxhost必须指定一个"
	exit
} elseif ( "$cluster" -ne "" -and "$esxhost" -ne ""){
	write-host "集群名称cluster和ESXi主机名esxhost同时只能指定一个"
	exit
}

function connect(){
	if ( (Get-PSSnapin -Name 'VMware.VimAutomation.Core' -ErrorAction SilentlyContinue) -eq $null ){
		Add-Pssnapin 'VMware.VimAutomation.Core' -ErrorAction SilentlyContinue
	}

	if($global:DefaultVIServer){
		Write-Host "vCenter Connection found. Disconnecting to continue..."
		Disconnect-ViServer -Server * -Confirm:$False -Force
	}

	Write-Host "Connecting to [$viserver]" -ForegroundColor Yellow

	$connection = connect-viserver $viserver -User $username -Password $password

	if($connection.isconnected -eq "true"){
		Write-Host "Connected!" -ForegroundColor Green
	}else{
		Write-Host "Something Went Wrong..." -ForegroundColor Red
		exit
	}

	Write-Host "StandBy .. gathering data!" -ForegroundColor Yellow
}


connect

if ( $cluster -eq "" ){
	$cluster = get-cluster -vmhost $esxhost
	$esxHosts = get-vmhost -name $esxhost
}else{
	$esxHosts = Get-VMHost -location $cluster | Where { $_.PowerState -eq "PoweredOn"} | Sort Name
}

$vms = Get-VM -location $cluster | Get-View

$report = @()
foreach($vm in $vms){
	foreach($dev in $vm.Config.Hardware.Device){
		if(($dev.gettype()).Name -eq "VirtualDisk"){
			if($dev.Backing.CompatibilityMode -eq "physicalMode"){
				$report += $dev.Backing.DeviceName
			}
		}
	}
}

$report = $report |select -uniq

foreach ($esxhost in $esxHosts){
	$esxcli= get-esxcli -VMHost $esxhost
	foreach($r in $report){
		$device = $esxcli.storage.core.device.list() | Where-Object {$_.OtherUids -like $r}
		$esxcli.storage.core.device.setconfig($false, $device.device, $true)
	}
}

Disconnect-VIServer $viserver -Confirm:$false -WarningAction SilentlyContinue
