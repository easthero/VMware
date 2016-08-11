param(
	[string]$viserver=$(throw "Parameter missing: -viserver vcenterip"),
	[string]$username=$(throw "Parameter missing: -username username"),
	[string]$password=$(throw ":Parameter missing: -password vcenterpassword"),
	[string]$oldpass=$(throw ":Parameter missing: -oldpass esxirootoldpass"),
	[string]$newpass=$(throw ":Parameter missing: -newpass esxirootnewpass"),
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

	if ( $cluster -ne "" ){
		$global:esxHosts = Get-VMHost -location $cluster | Where { $_.PowerState -eq "PoweredOn"} | Sort Name
	} else {
		$global:esxHosts = get-vmhost -name $esxhost
	}
}

connect
Disconnect-VIServer $viserver -Confirm:$false -WarningAction SilentlyContinue


foreach ($esx in $esxHosts){
	connect-viserver -server $esx -user root -password $oldpass -warningaction silentlycontinue 
	set-vmhostaccount -useraccount root -password "$newpass"
	disconnect-viserver -confirm:$false
	write-host "$esx password has changed"
}
