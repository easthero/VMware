param(
	[string]$viserver=$(throw "Parameter missing: -viserver vcenterip"),
	[string]$username=$(throw ":Parameter missing: -username vcenterusername"),
	[string]$password=$(throw ":Parameter missing: -password vcenterpassword"),
	[string]$task=$(throw ":Parameter missing: -task task"),
	[string]$cluster,
	[string]$esxhost
)

if ( "$cluster" -eq "" -and "$esxhost" -eq "" ){
	write-host "��Ⱥ����cluster��ESXi������esxhost����ָ��һ��"
	exit
} elseif ( "$cluster" -ne "" -and "$esxhost" -ne ""){
	write-host "��Ⱥ����cluster��ESXi������esxhostͬʱֻ��ָ��һ��"
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


#����
function dohelp($esxHosts){
	write-host "enablesshd			����ssh����"
	write-host "disablesshd			����ssh����"
	write-host "enterlockdownmode		��������ģʽ"
	write-host "exitlockdownmode		�˳�����ģʽ"
	write-host "checkpassword			������븴�Ӷ�"
	write-host "fixpassword			�������븴�Ӷ�"
	write-host "checkwebaccess			���webaccess����ǽ����"
	write-host "fixwebaccess			����webaccess����ǽ����"
	write-host "checkwelcomepage		����Ƿ�ر�web��ӭҳ��"
	write-host "fixwelcomepage			�ر�web��ӭҳ��"
	write-host "checklogdir			���־�����־����"
	write-host "fixlogdir			���ó־�����־"
	write-host "checklogsend			��鷢��syslog��Զ�̷���������"
	write-host "fixlogsend			���÷���syslog��Զ�̷�����"
	write-host "checkntp			���ntpʱ��ͬ������"	
	write-host "fixntp				����ntpʱ��ͬ��"	
	write-host "checksnmp			���snmp��������"
	write-host "fixsnmp				�ر�snmp����"
	write-host "checklockdownmode		����Ƿ�������ģʽ"
	write-host "checkdcui			���dcui�Ƿ�ر�" 
	write-host "fixdcui				�ر�dcui" 
	write-host "checkesxishell			���esxi shell�Ƿ�ر�" 
	write-host "fixesxishell			�ر�esxi shell" 
	write-host "checkesxishelltimeout		���esxi shell��ʱ����"
	write-host "fixesxishelltimeout		����esxi shell��ʱ"
	write-host "checkvsphereclient		���vsphereclient����ǽ����"
	write-host "fixvsphereclient		����vsphereclient����ǽ����"
	write-host "checkall			���������"			
	write-host "fixall				����������"			
	write-host "fixall2				�����������webaccess����ǽwebclient����ǽntp����"			
	exit
}

#����ssh����
function enablesshd($esxHosts){
	foreach($esx in $esxHosts){
		write-host "���� $esx ������ssh����"
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "TSM-SSH"} | Start-VMHostService
		write-host
	}
}

#�ر�ssh����
function disablesshd($esxHosts){
	foreach($esx in $esxHosts){
		write-host "�ر� $esx ������ssh����"
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "TSM-SSH"} | Stop-VMHostService -Confirm:$false
		write-host
	}
}

#��������ģʽ
function enterlockdownmode($esxHosts){
	foreach($esx in $esxHosts){
		Write-host "���� $esx ������������ģʽ"
		if ( "$esxhost" -eq ""){
			(get-vmhost -name $esx | get-view).enterLockdownMode()
		}else{
			($esx | get-view).enterLockdownMode()
		}
		write-host
	}
}

#�˳�����ģʽ
function exitlockdownmode($esxHosts){
	foreach($esx in $esxHosts){
		Write-host "���� $esx �����˳�����ģʽ"
		if ( "$esxhost" -eq "" ){
			(get-vmhost -name $esx | get-view).exitLockdownMode()
		}else{
			($esx | get-view).exitLockdownMode()
		}
		write-host
	}
}

#������븴�Ӷȣ����ǰ��Ҫ����ssh
function checkpasswordcomplexity($esxHosts){
	#���·���ֻ֧��esxi6.0, 5.5��Ҫʹ��ssh�����
	#Get-AdvancedSetting -Entity $esx -Name Security.PasswordQualityControl | Select Entity,Name,Value | Export-CSV -NoTypeInformation -Append -path esxi.csv

	foreach($esx in $esxHosts){
		Write-Host "��� $esx ���������븴�Ӷ�����"
		echo y |.\plink.exe -ssh -noagent $esx -l root -pw transfar 'grep -q min=8 /etc/pam.d/passwd; if [ $? -eq 0 ];then echo ���븴�Ӷ�δ���� ; else echo ���븴�Ӷ�������;fi'
		write-host
	}
}
		
#�������븴�Ӷȣ�����ǰ��Ҫ����ssh
function fixpasswordcomplexity($esxHosts){
	#���·���ֻ֧��esxi6.0, 5.5��Ҫʹ��ssh������
	#Get-AdvancedSetting -entity $esx -name Security.PasswordQualityControl  |Set-AdvancedSetting -value "min=disabled,disabled,disabled,8,8 passphrase=0 similar=deny enforce=everyone retry=3 random=0" -Confirm:$false

	foreach($esx in $esxHosts){
		Write-Host "���� $esx ���������븴�Ӷ�"
		echo y |.\plink.exe -ssh -noagent $esx -l root -pw transfar 'echo password requisite /lib/security/\$ISA/pam_passwdqc.so min=disabled,disabled,disabled,8,8 passphrase=0 similar=deny enforce=everyone retry=3 random=0 > /etc/pam.d/passwd; echo password sufficient   /lib/security/\$ISA/pam_unix.so use_authtok nullok shadow sha512 >> /etc/pam.d/passwd ; echo password required /lib/security/\$ISA/pam_deny.so >> /etc/pam.d/passwd '
		write-host
	}
}

#���webaccess����ǽ����,���ǰ��Ҫ�˳�����ģʽ
function checkwebaccess($esxHosts){
	foreach($esx in $esxHosts){
		$esxcli=Get-EsxCli -vmhost $esx	
		Write-Host "��� $esx ������webaccess����ǽ����"
		($esxcli.network.firewall.ruleset.allowedip.list() | ?{$_.Ruleset -eq "webAccess"}).AllowedIPAddresses
		write-host
	}
}

#����webaccess����ǽ����,����ǰ��Ҫ�˳�����ģʽ
function fixwebaccess($esxHosts){
	foreach($esx in $esxHosts){
		$esxcli=Get-EsxCli -vmhost $esx		 			
		Write-Host "���� $esx ������webaccess����ǽ����"
		$esxcli.network.firewall.ruleset.set($false,$true,"webAccess")
		$esxcli.network.firewall.ruleset.allowedip.add("3.176.0.203","webAccess")
		$esxcli.network.firewall.ruleset.allowedip.add("3.176.0.206","webAccess")
		$esxcli.network.firewall.ruleset.allowedip.add("3.176.0.207","webAccess")
		$esxcli.network.firewall.ruleset.allowedip.add("134.176.112.10","webAccess")
		$esxcli.network.firewall.ruleset.allowedip.add("134.175.30.10","webAccess")
		$esxcli.network.firewall.ruleset.allowedip.add("134.175.30.11","webAccess")
		write-host
	}
}

#����Ƿ����web��ӭҳ�棬���ǰ��Ҫ����ssh
function checkwelcomepage($esxHosts){
	foreach($esx in $esxHosts){
		Write-host "��� $esx �����Ƿ����web��ӭҳ��"
		echo y |.\plink.exe -ssh -noagent $esx -l root -pw transfar 'vim-cmd proxysvc/service_list|grep -q \"serverNamespace = \\\"/\\\"\"; if [ $? -eq 0 ];then echo web��ӭҳ��δ���� ; else echo web��ӭҳ���ѽ���;fi'
		write-host
	}
}

#���ý���web��ӭҳ�棬����ǰ��Ҫ����ssh
function fixwelcomepage($esxHosts){
	foreach($esx in $esxHosts){
		Write-host "���� $esx ��������web��ӭҳ��"
		echo y |.\plink.exe -ssh -noagent $esx -l root -pw transfar 'vim-cmd proxysvc/remove_service "/" httpsWithRedirect'
		write-host
	}
}

#���־�����־
function checklogdir($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "��� $esx �����Ƿ����ó־�����־"
		Get-AdvancedSetting -Entity $esx -Name syslog.global.logdir | Select Entity,Name,Value 
		write-host
	}
}

#���ó־�����־
#�´β���һ�£�����Ŀ¼��ʱ���ǲ��ǻ��Զ�����logdirĿ¼
function fixlogdir($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "���� $esx �����־�����־"

		$vmfsinfo = Get-Datastore -VMHost $esx | ?{$_.ExtensionData.Summary.MultipleHostAccess -eq $false} |Select {$_.ExtensionData.Info.Vmfs.name}
		$datastorename = $vmfsinfo.'$_.ExtensionData.Info.Vmfs.name'
				
		New-PSDrive -Name "mounteddatastore" -Root \ -PSProvider VimDatastore -Datastore (Get-Datastore $datastorename)
		$currlocation=pwd
		Set-Location mounteddatastore:
#		New-Item "esx-logs" -ItemType directory
		set-location $currlocation
		remove-psdrive -name "mounteddatastore"
		Get-AdvancedSetting -entity $esx -name syslog.global.logdir  |Set-AdvancedSetting -value "[]/vmfs/volumes/$datastorename/esx-logs" -Confirm:$false
		write-host
	}
}

#�����־�Ƿ����÷��͵���־������
function checklogsend($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "��� $esx �����Ƿ����÷�����־����־������"
		Get-AdvancedSetting -Entity $esx -Name syslog.global.loghost | Select Entity,Name,Value 
		write-host
	}
}

#������־���͵���־������
function fixlogsend($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "���� $esx ��־���͵���־������"
		Get-AdvancedSetting -entity $esx -name syslog.global.loghost  |Set-AdvancedSetting -value "udp://192.168.36.5:514" -Confirm:$false
		write-host
	}
}

#���ntp����
function checkntp($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "��� $esx �����Ƿ�����ntp������"
		Get-VMHost -name $esx | Select-Object @{Name="entity";Expression={$esx}}, @{Name="name"; Express={"NTP�Ƿ�����::NTP��������ַ"}}, @{Name="Value";Expression={ [system.convert]::tostring(($_ | Get-VMHostService | Where-Object {$_.key -eq "ntpd"}).Running)  + "::" +  ($_ | Get-VMHostNtpServer) }}  
		write-host
	}
}

#����ntpʱ��ͬ��
function fixntp($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "���� $esx ������ntp����������ʱ��ͬ��"
		get-vmhost -name $esx |add-vmhostntpserver "134.175.6.232"
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "ntpd"} | Start-VMHostService -Confirm:$false
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "ntpd"} | set-VMHostService -policy on
		write-host
	}
}

#���snmpd����
function checksnmp($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "��� $esx �����Ƿ�����snmp������"
		$esxcli=Get-EsxCli -vmhost $esx		 			
		1 |select-object @{Name="entity";Expression={$esx}}, @{Name="name"; Expression={"SNMP�Ƿ�����::SNMP����Ŀ��::SNMP��ͬ��"}}, @{Name="value"; Expression = {  ($esxcli.system.snmp.get()|select-object -property enable).enable + " :: " + ($esxcli.system.snmp.get()|select-object -property targets).targets + " :: " + ($esxcli.system.snmp.get()|select-object -property communities).communities }}	
		write-host
	}
}


#���ý���snmpd����			
function fixsnmp($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "���� $esx ��������snmp����"
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "snmpd"} | Stop-VMHostService -Confirm:$false
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "snmpd"} | set-VMHostService -policy off
		write-host
	}
}
	
#����Ƿ���������ģʽ
function checklockdownmode($esxHosts){
	#5.5�Ǽ�� config.AdminDisabled 6.0���config.LockdownMode
	foreach($esx in $esxHosts){
		Write-Host "��� $esx �����Ƿ�����������ģʽ"
		1 |select-object @{Name="entity";Expression={$esx}}, @{Name="name"; Expression={"�Ƿ�����������ģʽ"}}, @{Name="value"; Expression = { (get-vmhost -name $esx |get-view ).config.AdminDisabled }} 
		write-host
	}
}

#����Ƿ����dcui
function checkdcui($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "��� $esx �����Ƿ������DCUI"
		Get-VMHost -name $esx | Select-Object @{Name="entity";Expression={$esx}}, @{Name="name"; Express={"DCUI�Ƿ���������"}}, @{Name="Value";Expression={ [system.convert]::tostring(($_ | Get-VMHostService | Where-Object {$_.key -eq "DCUI"}).Running) }} 
		write-host
	}
}

#����dcui
function fixdcui($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "���� $esx ��������DCUI"
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "DCUI"} | Stop-VMHostService -Confirm:$false
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "DCUI"} | set-VMHostService -policy off
		write-host
	}
}

#����Ƿ����esxishell
function checkesxishell($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "��� $esx �����Ƿ���������esxi shell"
		Get-VMHost -name $esx | Select-Object @{Name="entity";Expression={$esx}}, @{Name="name"; Express={"esxi shell�Ƿ���������"}}, @{Name="Value";Expression={ [system.convert]::tostring(($_ | Get-VMHostService | Where-Object {$_.key -eq "TSM"}).Running) }} 
		write-host
	}
}

#����esxishell
function fixesxishell($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "���� $esx ��������esxi shell"
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "TSM"} | Stop-VMHostService -Confirm:$false
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "TSM"} | set-VMHostService -policy off
		write-host
	}
}

#���esxishell��ʱʱ��
function checkesxishelltimeout($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "��� $esx �����ļ���֧��ģʽ��ʱʱ��"
		Get-AdvancedSetting -Entity $esx -Name UserVars.ESXiShellTimeOut | Select Entity,Name,Value 
		write-host
	}
}

#����esxishell��ʱʱ��Ϊ900��
function fixesxishelltimeout($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "���� $esx �����ļ���֧��ģʽ��ʱʱ��Ϊ900��"
		Get-AdvancedSetting -entity $esx -name UserVars.ESXiShellTimeOut  |Set-AdvancedSetting -value "900" -Confirm:$false
		write-host
	}
}

#���vsphereclient����ǽ����
function checkvsphereclient($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "��� $esx ��vSphere Client����ǽ����"
		$esxcli=Get-EsxCli -vmhost $esx		 			
		($esxcli.network.firewall.ruleset.allowedip.list() | ?{$_.Ruleset -eq "vSphereClient"}).AllowedIPAddresses
		write-host
	}
}

#����vsphereclient����ǽ����
function fixvsphereclient($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "���� $esx ��vSphere Client����ǽ����"
		$esxcli=Get-EsxCli -vmhost $esx		 			
		$esxcli.network.firewall.set($null, $false)
		$esxcli.network.firewall.ruleset.set($false,$true,"vSphereClient")
		$esxcli.network.firewall.ruleset.allowedip.add("3.176.0.203","vSphereClient")
		$esxcli.network.firewall.ruleset.allowedip.add("3.176.0.206","vSphereClient")
		$esxcli.network.firewall.ruleset.allowedip.add("3.176.0.207","vSphereClient")
		$esxcli.network.firewall.ruleset.allowedip.add("134.176.112.10","vSphereClient")
		$esxcli.network.firewall.ruleset.allowedip.add("134.175.30.10","vSphereClient")
		$esxcli.network.firewall.ruleset.allowedip.add("134.175.30.11","vSphereClient")
		$esxcli.network.firewall.refresh()
		$esxcli.network.firewall.set($null, $true)
		write-host
	}
}

#����Ƿ���������ģʽ
function lockdownmode($esxHosts){
	#5.5�Ǽ�� config.AdminDisabled 6.0���config.LockdownMode
	foreach($esx in $esxHosts){
		Write-Host "��� $esx �����Ƿ�����������ģʽ"
		1 |select-object @{Name="entity";Expression={$esx}}, @{Name="name"; Expression={"�Ƿ�����������ģʽ"}}, @{Name="value"; Expression = { (get-vmhost -name $esx |get-view ).config.AdminDisabled }} 
		write-host
	}
}

function checkall($esxHosts){
	checkpasswordcomplexity($esxHosts)
	checkwebaccess($esxHosts)
	checkwelcomepage($esxHosts)
	checklogdir($esxHosts)
	checklogsend($esxHosts)
	checkntp($esxHosts)
	checksnmp($esxHosts)
	checkdcui($esxHosts)
	checkesxishell($esxHosts)
	checkesxishelltimeout($esxHosts)
	checkvsphereclient($esxHosts)
}

#��Ҫ������������־�ģ��Ͱ�fixlogsendע�͵�
function fixall($esxHosts){
	fixpasswordcomplexity($esxHosts)
	fixwebaccess($esxHosts)
	fixwelcomepage($esxHosts)
	fixlogdir($esxHosts)
#	fixlogsend($esxHosts)
	fixntp($esxHosts)
	fixsnmp($esxHosts)
	fixdcui($esxHosts)
	fixesxishell($esxHosts)
	fixesxishelltimeout($esxHosts)
	fixvsphereclient($esxHosts)
}

function fixall2($esxHosts){
	fixpasswordcomplexity($esxHosts)
#	fixwebaccess($esxHosts)
	fixwelcomepage($esxHosts)
	fixlogdir($esxHosts)
#	fixlogsend($esxHosts)
#	fixntp($esxHosts)
	fixsnmp($esxHosts)
	fixdcui($esxHosts)
	fixesxishell($esxHosts)
	fixesxishelltimeout($esxHosts)
#	fixvsphereclient($esxHosts)
}

#������

#���ڼ�����븴�Ӷȵȸ���������Ҫ�ǵ�esxi�������ϼ�飬�������ģʽ��ssh���������
#�ڼ��ǰ�ֶ��ر�����ģʽ������ssh����
#�ڼ����ֶ���������ģʽ���ر�ssh����

switch ($task){
	"enablesshd"					{ connect; enablesshd($esxHosts) }
	"disablesshd"					{ connect; disablesshd($esxHosts) }
	"enterlockdownmode"				{ connect; enterlockdownmode($esxHosts) }
	"exitlockdownmode"				{ connect; exitlockdownmode($esxHosts) }
	"checkpassword"						{ connect; checkpasswordcomplexity($esxHosts) }
	"fixpassword"						{ connect; fixpasswordcomplexity($esxHosts) }
	"checkwebaccess"						{ connect; checkwebaccess($esxHosts) }
	"fixwebaccess"						{ connect; fixwebaccess($esxHosts) }
	"checkwelcomepage"					{ connect; checkwelcomepage($esxHosts) }
	"fixwelcomepage"					{ connect; fixwelcomepage($esxHosts) }
	"checklogdir"						{ connect; checklogdir($esxHosts) }
	"fixlogdir"						{ connect; fixlogdir($esxHosts) }
	"checklogsend"						{ connect; checklogsend($esxHosts) }
	"fixlogsend"						{ connect; fixlogsend($esxHosts) }
	"checkntp"							{ connect; checkntp($esxHosts) }
	"fixntp"							{ connect; fixntp($esxHosts) }
	"checksnmp"							{ connect; checksnmp($esxHosts) }
	"fixsnmp"							{ connect; fixsnmp($esxHosts) }
	"checklockdownmode"					{ connect; checklockdownmode($esxHosts) }
	"checkdcui"							{ connect; checkdcui($esxHosts) }
	"fixdcui"							{ connect; fixdcui($esxHosts) }
	"checkesxishell"						{ connect; checkesxishell($esxHosts) }
	"fixesxishell"						{ connect; fixesxishell($esxHosts) }
	"checkesxishelltimeout"				{ connect; checkesxishelltimeout($esxHosts) }
	"fixesxishelltimeout"				{ connect; fixesxishelltimeout($esxHosts) }
	"checkvsphereclient"					{ connect; checkvsphereclient($esxHosts) }
	"fixvsphereclient"					{ connect; fixvsphereclient($esxHosts) }
	"checkall"					{ connect; checkall($esxHosts) }
	"fixall"					{ connect; fixall($esxHosts) }
	"fixall2"					{ connect; fixall2($esxHosts) }
	default { dohelp }
}

Disconnect-VIServer $viserver -Confirm:$false -WarningAction SilentlyContinue
