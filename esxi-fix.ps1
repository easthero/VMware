param(
	[string]$viserver=$(throw "Parameter missing: -viserver vcenterip"),
	[string]$username=$(throw ":Parameter missing: -username vcenterusername"),
	[string]$password=$(throw ":Parameter missing: -password vcenterpassword"),
	[string]$task=$(throw ":Parameter missing: -task task"),
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


#帮助
function dohelp($esxHosts){
	write-host "enablesshd			启用ssh服务"
	write-host "disablesshd			禁用ssh服务"
	write-host "enterlockdownmode		启用锁定模式"
	write-host "exitlockdownmode		退出锁定模式"
	write-host "checkpassword			检查密码复杂度"
	write-host "fixpassword			配置密码复杂度"
	write-host "checkwebaccess			检查webaccess防火墙策略"
	write-host "fixwebaccess			配置webaccess防火墙策略"
	write-host "checkwelcomepage		检查是否关闭web欢迎页面"
	write-host "fixwelcomepage			关闭web欢迎页面"
	write-host "checklogdir			检查持久性日志配置"
	write-host "fixlogdir			配置持久性日志"
	write-host "checklogsend			检查发送syslog至远程服务器配置"
	write-host "fixlogsend			配置发送syslog至远程服务器"
	write-host "checkntp			检查ntp时间同步配置"	
	write-host "fixntp				配置ntp时间同步"	
	write-host "checksnmp			检查snmp服务配置"
	write-host "fixsnmp				关闭snmp服务"
	write-host "checklockdownmode		检查是否开启锁定模式"
	write-host "checkdcui			检查dcui是否关闭" 
	write-host "fixdcui				关闭dcui" 
	write-host "checkesxishell			检查esxi shell是否关闭" 
	write-host "fixesxishell			关闭esxi shell" 
	write-host "checkesxishelltimeout		检查esxi shell超时设置"
	write-host "fixesxishelltimeout		设置esxi shell超时"
	write-host "checkvsphereclient		检查vsphereclient防火墙策略"
	write-host "fixvsphereclient		配置vsphereclient防火墙策略"
	write-host "checkall			检查所有项"			
	write-host "fixall				配置所有项"			
	write-host "fixall2				配置所有项除webaccess防火墙webclient防火墙ntp三项"			
	exit
}

#开放ssh服务
function enablesshd($esxHosts){
	foreach($esx in $esxHosts){
		write-host "开放 $esx 主机的ssh服务"
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "TSM-SSH"} | Start-VMHostService
		write-host
	}
}

#关闭ssh服务
function disablesshd($esxHosts){
	foreach($esx in $esxHosts){
		write-host "关闭 $esx 主机的ssh服务"
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "TSM-SSH"} | Stop-VMHostService -Confirm:$false
		write-host
	}
}

#进入锁定模式
function enterlockdownmode($esxHosts){
	foreach($esx in $esxHosts){
		Write-host "设置 $esx 主机进入锁定模式"
		if ( "$esxhost" -eq ""){
			(get-vmhost -name $esx | get-view).enterLockdownMode()
		}else{
			($esx | get-view).enterLockdownMode()
		}
		write-host
	}
}

#退出锁定模式
function exitlockdownmode($esxHosts){
	foreach($esx in $esxHosts){
		Write-host "设置 $esx 主机退出锁定模式"
		if ( "$esxhost" -eq "" ){
			(get-vmhost -name $esx | get-view).exitLockdownMode()
		}else{
			($esx | get-view).exitLockdownMode()
		}
		write-host
	}
}

#检查密码复杂度，检查前先要开放ssh
function checkpasswordcomplexity($esxHosts){
	#以下方法只支持esxi6.0, 5.5需要使用ssh来检查
	#Get-AdvancedSetting -Entity $esx -Name Security.PasswordQualityControl | Select Entity,Name,Value | Export-CSV -NoTypeInformation -Append -path esxi.csv

	foreach($esx in $esxHosts){
		Write-Host "检查 $esx 主机的密码复杂度设置"
		echo y |.\plink.exe -ssh -noagent $esx -l root -pw transfar 'grep -q min=8 /etc/pam.d/passwd; if [ $? -eq 0 ];then echo 密码复杂度未设置 ; else echo 密码复杂度已设置;fi'
		write-host
	}
}
		
#配置密码复杂度，配置前先要开放ssh
function fixpasswordcomplexity($esxHosts){
	#以下方法只支持esxi6.0, 5.5需要使用ssh来配置
	#Get-AdvancedSetting -entity $esx -name Security.PasswordQualityControl  |Set-AdvancedSetting -value "min=disabled,disabled,disabled,8,8 passphrase=0 similar=deny enforce=everyone retry=3 random=0" -Confirm:$false

	foreach($esx in $esxHosts){
		Write-Host "配置 $esx 主机的密码复杂度"
		echo y |.\plink.exe -ssh -noagent $esx -l root -pw transfar 'echo password requisite /lib/security/\$ISA/pam_passwdqc.so min=disabled,disabled,disabled,8,8 passphrase=0 similar=deny enforce=everyone retry=3 random=0 > /etc/pam.d/passwd; echo password sufficient   /lib/security/\$ISA/pam_unix.so use_authtok nullok shadow sha512 >> /etc/pam.d/passwd ; echo password required /lib/security/\$ISA/pam_deny.so >> /etc/pam.d/passwd '
		write-host
	}
}

#检查webaccess防火墙设置,检查前先要退出锁定模式
function checkwebaccess($esxHosts){
	foreach($esx in $esxHosts){
		$esxcli=Get-EsxCli -vmhost $esx	
		Write-Host "检查 $esx 主机的webaccess防火墙设置"
		($esxcli.network.firewall.ruleset.allowedip.list() | ?{$_.Ruleset -eq "webAccess"}).AllowedIPAddresses
		write-host
	}
}

#配置webaccess防火墙策略,配置前先要退出锁定模式
function fixwebaccess($esxHosts){
	foreach($esx in $esxHosts){
		$esxcli=Get-EsxCli -vmhost $esx		 			
		Write-Host "配置 $esx 主机的webaccess防火墙策略"
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

#检查是否禁用web欢迎页面，检查前先要开放ssh
function checkwelcomepage($esxHosts){
	foreach($esx in $esxHosts){
		Write-host "检查 $esx 主机是否禁用web欢迎页面"
		echo y |.\plink.exe -ssh -noagent $esx -l root -pw transfar 'vim-cmd proxysvc/service_list|grep -q \"serverNamespace = \\\"/\\\"\"; if [ $? -eq 0 ];then echo web欢迎页面未禁用 ; else echo web欢迎页面已禁用;fi'
		write-host
	}
}

#配置禁用web欢迎页面，配置前先要开放ssh
function fixwelcomepage($esxHosts){
	foreach($esx in $esxHosts){
		Write-host "配置 $esx 主机禁用web欢迎页面"
		echo y |.\plink.exe -ssh -noagent $esx -l root -pw transfar 'vim-cmd proxysvc/remove_service "/" httpsWithRedirect'
		write-host
	}
}

#检查持久性日志
function checklogdir($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "检查 $esx 主机是否配置持久性日志"
		Get-AdvancedSetting -Entity $esx -Name syslog.global.logdir | Select Entity,Name,Value 
		write-host
	}
}

#配置持久性日志
#下次测试一下，不建目录的时候是不是会自动创建logdir目录
function fixlogdir($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "配置 $esx 主机持久性日志"

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

#检查日志是否配置发送到日志服务器
function checklogsend($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "检查 $esx 主机是否配置发送日志到日志服务器"
		Get-AdvancedSetting -Entity $esx -Name syslog.global.loghost | Select Entity,Name,Value 
		write-host
	}
}

#配置日志发送到日志服务器
function fixlogsend($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "配置 $esx 日志发送到日志服务器"
		Get-AdvancedSetting -entity $esx -name syslog.global.loghost  |Set-AdvancedSetting -value "udp://192.168.36.5:514" -Confirm:$false
		write-host
	}
}

#配查ntp配置
function checkntp($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "检查 $esx 主机是否配置ntp服务器"
		Get-VMHost -name $esx | Select-Object @{Name="entity";Expression={$esx}}, @{Name="name"; Express={"NTP是否启用::NTP服务器地址"}}, @{Name="Value";Expression={ [system.convert]::tostring(($_ | Get-VMHostService | Where-Object {$_.key -eq "ntpd"}).Running)  + "::" +  ($_ | Get-VMHostNtpServer) }}  
		write-host
	}
}

#配置ntp时间同步
function fixntp($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "配置 $esx 主机与ntp服务器进行时间同步"
		get-vmhost -name $esx |add-vmhostntpserver "134.175.6.232"
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "ntpd"} | Start-VMHostService -Confirm:$false
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "ntpd"} | set-VMHostService -policy on
		write-host
	}
}

#检查snmpd配置
function checksnmp($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "检查 $esx 主机是否配置snmp服务器"
		$esxcli=Get-EsxCli -vmhost $esx		 			
		1 |select-object @{Name="entity";Expression={$esx}}, @{Name="name"; Expression={"SNMP是否启用::SNMP发送目标::SNMP共同体"}}, @{Name="value"; Expression = {  ($esxcli.system.snmp.get()|select-object -property enable).enable + " :: " + ($esxcli.system.snmp.get()|select-object -property targets).targets + " :: " + ($esxcli.system.snmp.get()|select-object -property communities).communities }}	
		write-host
	}
}


#配置禁用snmpd服务			
function fixsnmp($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "配置 $esx 主机禁用snmp服务"
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "snmpd"} | Stop-VMHostService -Confirm:$false
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "snmpd"} | set-VMHostService -policy off
		write-host
	}
}
	
#检查是否启用锁定模式
function checklockdownmode($esxHosts){
	#5.5是检查 config.AdminDisabled 6.0检查config.LockdownMode
	foreach($esx in $esxHosts){
		Write-Host "检查 $esx 主机是否启用了锁定模式"
		1 |select-object @{Name="entity";Expression={$esx}}, @{Name="name"; Expression={"是否启用了锁定模式"}}, @{Name="value"; Expression = { (get-vmhost -name $esx |get-view ).config.AdminDisabled }} 
		write-host
	}
}

#检查是否禁用dcui
function checkdcui($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "检查 $esx 主机是否禁用了DCUI"
		Get-VMHost -name $esx | Select-Object @{Name="entity";Expression={$esx}}, @{Name="name"; Express={"DCUI是否正在运行"}}, @{Name="Value";Expression={ [system.convert]::tostring(($_ | Get-VMHostService | Where-Object {$_.key -eq "DCUI"}).Running) }} 
		write-host
	}
}

#禁用dcui
function fixdcui($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "配置 $esx 主机禁用DCUI"
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "DCUI"} | Stop-VMHostService -Confirm:$false
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "DCUI"} | set-VMHostService -policy off
		write-host
	}
}

#检查是否禁用esxishell
function checkesxishell($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "检查 $esx 主机是否正在运行esxi shell"
		Get-VMHost -name $esx | Select-Object @{Name="entity";Expression={$esx}}, @{Name="name"; Express={"esxi shell是否正在运行"}}, @{Name="Value";Expression={ [system.convert]::tostring(($_ | Get-VMHostService | Where-Object {$_.key -eq "TSM"}).Running) }} 
		write-host
	}
}

#禁用esxishell
function fixesxishell($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "配置 $esx 主机禁用esxi shell"
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "TSM"} | Stop-VMHostService -Confirm:$false
		Get-VMHostService -VMHost $esx | ?{$_.Key -eq "TSM"} | set-VMHostService -policy off
		write-host
	}
}

#检查esxishell超时时间
function checkesxishelltimeout($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "检查 $esx 主机的技术支持模式超时时间"
		Get-AdvancedSetting -Entity $esx -Name UserVars.ESXiShellTimeOut | Select Entity,Name,Value 
		write-host
	}
}

#配置esxishell超时时间为900秒
function fixesxishelltimeout($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "设置 $esx 主机的技术支持模式超时时间为900秒"
		Get-AdvancedSetting -entity $esx -name UserVars.ESXiShellTimeOut  |Set-AdvancedSetting -value "900" -Confirm:$false
		write-host
	}
}

#检查vsphereclient防火墙策略
function checkvsphereclient($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "检查 $esx 的vSphere Client防火墙设置"
		$esxcli=Get-EsxCli -vmhost $esx		 			
		($esxcli.network.firewall.ruleset.allowedip.list() | ?{$_.Ruleset -eq "vSphereClient"}).AllowedIPAddresses
		write-host
	}
}

#配置vsphereclient防火墙策略
function fixvsphereclient($esxHosts){
	foreach($esx in $esxHosts){
		Write-Host "配置 $esx 的vSphere Client防火墙策略"
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

#检查是否启用锁定模式
function lockdownmode($esxHosts){
	#5.5是检查 config.AdminDisabled 6.0检查config.LockdownMode
	foreach($esx in $esxHosts){
		Write-Host "检查 $esx 主机是否启用了锁定模式"
		1 |select-object @{Name="entity";Expression={$esx}}, @{Name="name"; Expression={"是否启用了锁定模式"}}, @{Name="value"; Expression = { (get-vmhost -name $esx |get-view ).config.AdminDisabled }} 
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

#不要做主机发送日志的，就把fixlogsend注释掉
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

#任务项

#由于检查密码复杂度等个别配置需要登到esxi服务器上检查，因此锁定模式和ssh服务不做检查
#在检查前手动关闭锁定模式并开启ssh服务
#在检查后手动开启锁定模式并关闭ssh服务

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
