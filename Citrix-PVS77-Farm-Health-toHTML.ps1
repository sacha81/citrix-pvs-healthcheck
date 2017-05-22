#==============================================================================================
# Created on: 12/2015            Version: 1.3
# Created by: Sacha Thomet, blog.appcloud.ch / sachathomet.ch
# Filename: Citrix-PVS77-Farm-Health-toHTML.ps1
#
#
# Description: This script checks some Citrix Provisioning Server, Farm, vDisk & Target device parameters.
# 
# This Script is working on PVS 7.7 and higher, for older PVS Version (7.6 and below) use the Script here:
# http://blog.appcloud.ch/citrix-pvs-healthcheck/
#
# Prerequisite: Script must run on a PVS server, where PVS snap-in is registered with this command:
# 1. set-alias installutil C:\Windows\Microsoft.NET\Framework64\v4.0.30319\installutil.exe
# 2. installutil "C:\Program Files\Citrix\Provisioning Services Console\Citrix.PVS.SnapIn.dll"
# 3. Add-PSSnapin Citrix*
#
# Call by : Scheduled Task, e.g. once a day
#
# Change Log: 
#      	V0.9: Creation of the Script based on the Script used for PVS 7.6 and below.
#      		  - Change all the PoSh commands from the mcli-get to PVS-Get...
#      		  - Creation of functions for each test sequence
#      		  - Add Service-Checks for PVS-Servers 
#
#      	V1.0: Update that the Script works with PVS 7.7 final version. (Name of the Snapin is now Citrix.PVS.SnapIn)
#      	V1.1: Performance-Update, Timeout for get-content personality.ini, Target-Device table at latest in report
#      	V1.2: - Bug fixes (vDisk state, if one vDisk version is proper synced background is green)
#      		  - Free Disk Space on PVS Servers (Thanks to Jay )
#      	V1.3: Add some modifications to make the script similar to XD-XD Healt Check
#      		  - Variable $EnvironmentName added like XD-XA script to "generate" header
#      		  - Created timestamp report as variable $ReportDate
#      		  - $EnvName and $emailSubject redefined in the report generation
#      		  - Configuration via an XML file
#      		  - Redefined display the date for the report
#      		  - Replaced generate the date in the second place by variable
#
#==============================================================================================
if ((Get-PSSnapin "Citrix.PVS.SnapIn" -EA silentlycontinue) -eq $null) {
try { Add-PSSnapin Citrix.PVS.SnapIn -ErrorAction Stop }
catch { write-error "Error loading Citrix.PVS.SnapIn PowerShell snapin"; Return }
}
# Change the below variables to suit your environment
#==============================================================================================
# Import Variables from XML:
If (![string]::IsNullOrEmpty($hostinvocation)) {
	[string]$Script:ScriptPath = [System.IO.Path]::GetDirectoryName([System.Windows.Forms.Application]::ExecutablePath)
	[string]$Script:ScriptFile = [System.IO.Path]::GetFileName([System.Windows.Forms.Application]::ExecutablePath)
	[string]$Script:ScriptName = [System.IO.Path]::GetFileNameWithoutExtension([System.Windows.Forms.Application]::ExecutablePath)
} ElseIf ($Host.Version.Major -lt 3) {
	[string]$Script:ScriptPath = Split-Path -parent $MyInvocation.MyCommand.Definition
	[string]$Script:ScriptFile = Split-Path -Leaf $script:MyInvocation.MyCommand.Path
	[string]$Script:ScriptName = $ScriptFile.Split('.')[0].Trim()
} Else {
	[string]$Script:ScriptPath = $PSScriptRoot
	[string]$Script:ScriptFile = Split-Path -Leaf $PSCommandPath
	[string]$Script:ScriptName = $ScriptFile.Split('.')[0].Trim()
}

#Set-StrictMode -Version Latest

# Import parameter file
$Script:ParameterFile = $ScriptName + "_Parameters.xml"
$Script:ParameterFilePath = $ScriptPath
[xml]$cfg = Get-Content ($ParameterFilePath + "\" + $ParameterFile) # Read content of XML file

# Import variables
Function New-XMLVariables {
	# Create a variable reference to the XML file
	$cfg.Settings.Variables.Variable | foreach {
		# Set Variables contained in XML file
		$VarValue = $_.Value
		$CreateVariable = $True # Default value to create XML content as Variable
		switch ($_.Type) {
			# Format data types for each variable 
			'[string]' { $VarValue = [string]$VarValue } # Fixed-length string of Unicode characters
			'[char]' { $VarValue = [char]$VarValue } # A Unicode 16-bit character
			'[byte]' { $VarValue = [byte]$VarValue } # An 8-bit unsigned character
            '[bool]' { If ($VarValue.ToLower() -eq 'false'){$VarValue = [bool]$False} ElseIf ($VarValue.ToLower() -eq 'true'){$VarValue = [bool]$True} } # An boolean True/False value
			'[int]' { $VarValue = [int]$VarValue } # 32-bit signed integer
			'[long]' { $VarValue = [long]$VarValue } # 64-bit signed integer
			'[decimal]' { $VarValue = [decimal]$VarValue } # A 128-bit decimal value
			'[single]' { $VarValue = [single]$VarValue } # Single-precision 32-bit floating point number
			'[double]' { $VarValue = [double]$VarValue } # Double-precision 64-bit floating point number
			'[DateTime]' { $VarValue = [DateTime]$VarValue } # Date and Time
			'[Array]' { $VarValue = [Array]$VarValue.Split(',') } # Array
			'[Command]' { $VarValue = Invoke-Expression $VarValue; $CreateVariable = $False } # Command
		}
		If ($CreateVariable) { New-Variable -Name $_.Name -Value $VarValue -Scope $_.Scope -Force }
	}
}

New-XMLVariables

$ReportDate = (Get-Date -UFormat "%A, %d. %B %Y %R")

# 
# Information about the site you want to check:    --------------------------------------------
#$siteName="Unico Cloud" # site name on which the according Store is.
# Target Device Health Check threshold:            --------------------------------------------
#$retrythresholdWarning= "15" # define the Threshold from how many retries the color switch to red
# 
# Include for Device Collections, type "every" if you want to see every Collection 
# Example1: $Collections = @("XA65","XA7")
# Example2: $Collections = @("every")
#$Collections = @("every")
# 
# Information about your Email infrastructure:      --------------------------------------------
# E-mail report details
#$emailFrom = "email@company.ch"
#$emailTo = "citrix@company.ch"#,"sacha.thomet@appcloud.ch"
#$smtpServer = "mailrelay.company.ch"
#$emailSubjectStart = "PVS Farm Report"
#$mailprio = "High"
# 
# Check's &amp;amp; Jobs you want to perform
#$PerformPVSvDiskCheck = "yes"
#$PerformPVSTargetCheck = "yes"
#$PerformSendMail = "yes"
# 
# 
#Don't change below here if you don't know what you are doing ... 
#==============================================================================================
 
$currentDir = Split-Path $MyInvocation.MyCommand.Path
$outputpath = Join-Path $currentDir "" #add here a custom output folder if you wont have it on the same directory
$outputdate = Get-Date -Format 'yyyyMMddHHmm'
$logfile = Join-Path $outputpath ("PVSHealthCheck.log")
$resultsHTM = Join-Path $outputpath ("PVSFarmReport.htm") #add $outputdate in filename if you like
$errorsHTM = Join-Path $currentDir ("PVSHealthCheckErrors.htm") 

if ($PerformPVSTargetCheck -eq "yes") {
#Header for Table 1 "Target Device Checks"
$TargetfirstheaderName = "TargetDeviceName"
$TargetheaderNames = "CollectionName", "Ping", "Retry", "vDisk_PVS", "vDisk_Version", "WriteCache", "PVSServer"
$TargetheaderWidths = "4", "4", "4", "4", "2" , "4", "4"
$Targettablewidth = 1200
} 

if ($PerformPVSvDiskCheck -eq "yes") {
#Header for Table 2 "vDisk Checks"
$vDiksFirstheaderName = "vDiskName"
$vDiskheaderNames = "Site", "Store", "vDiskFileName", "deviceCount", "CreateDate" , "ReplState", "LoadBalancingAlgorithm", "WriteCacheType"
$vDiskheaderWidths = "4","4", "8", "2","4", "4", "4", "4"
$vDisktablewidth = 1200
}

#Header for Table 3 "PV Server"
$PVSfirstheaderName = "PVS Server"
$PVSHeaderNames = "Ping", "Active", "deviceCount","SoapService","StreamService","TFTPService"
$PVSheaderWidths = "8", "4", "4","4","4","4"
$PVStablewidth = 800
foreach ($disk in $diskLetters)
{
    $PVSHeaderNames += "$($disk)Freespace"
    $PVSheaderWidths += "4"
}
$PVSHeaderNames += "AvgCPU","MemUsg"
$PVSheaderWidths += "4","4"


#Header for Table 4 "Farm"
$PVSFirstFarmheaderName = "Farm"
$PVSFarmHeaderNames = "DBServerName", "DatabaseName", "OfflineDB", "LicenseServer"
$PVSFarmWidths = "4", "4", "4", "4"
$PVSFarmTablewidth = 400

 
#==============================================================================================
#log function
function LogMe() {
Param(
[parameter(Mandatory = $true, ValueFromPipeline = $true)] $logEntry,
[switch]$display,
[switch]$error,
[switch]$warning,
[switch]$progress
)
 
 if ($error) {
$logEntry = "[ERROR] $logEntry" ; Write-Host "$logEntry" -Foregroundcolor Red}
elseif ($warning) {
Write-Warning "$logEntry" ; $logEntry = "[WARNING] $logEntry"}
elseif ($progress) {
Write-Host "$logEntry" -Foregroundcolor Green}
elseif ($display) {
Write-Host "$logEntry" }
  
 #$logEntry = ((Get-Date -uformat "%D %T") + " - " + $logEntry)
$logEntry | Out-File $logFile -Append
}
#==============================================================================================
function Ping([string]$hostname, [int]$timeout = 200) {
$ping = new-object System.Net.NetworkInformation.Ping #creates a ping object
try {
$result = $ping.send($hostname, $timeout).Status.ToString()
} catch {
$result = "Failure"
}
return $result
}
#==============================================================================================
# The function will check the processor counter and check for the CPU usage. Takes an average CPU usage for 5 seconds. It check the current CPU usage for 5 secs.
Function CheckCpuUsage() 
{ 
	param ($hostname)
	Try { $CpuUsage=(get-counter -ComputerName $hostname -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 5 -ErrorAction Stop | select -ExpandProperty countersamples | select -ExpandProperty cookedvalue | Measure-Object -Average).average
    	$CpuUsage = "{0:N1}" -f $CpuUsage; return $CpuUsage
	} Catch { "Error returned while checking the CPU usage. Perfmon Counters may be fault" | LogMe -error; return 101 } 
}
#============================================================================================== 
# The function check the memory usage and report the usage value in percentage
Function CheckMemoryUsage() 
{ 
	param ($hostname)
    Try 
	{   $SystemInfo = (Get-WmiObject -computername $hostname -Class Win32_OperatingSystem -ErrorAction Stop | Select-Object TotalVisibleMemorySize, FreePhysicalMemory)
    	$TotalRAM = $SystemInfo.TotalVisibleMemorySize/1MB 
    	$FreeRAM = $SystemInfo.FreePhysicalMemory/1MB 
    	$UsedRAM = $TotalRAM - $FreeRAM 
    	$RAMPercentUsed = ($UsedRAM / $TotalRAM)
    	return $RAMPercentUsed
	} Catch { "Error returned while checking the Memory usage. Perfmon Counters may be fault" | LogMe -error; return 1.01f } 
}
#==============================================================================================
Function writeHtmlHeader
{
param($title, $fileName)
$date = $ReportDate
$head = @"
<html>
<head>
<meta http-equiv='Content-Type' content='text/html; charset=iso-8859-1'>
<title>$title</title>
<STYLE TYPE="text/css">
<!--
td {
font-family: Tahoma;
font-size: 11px;
border-top: 1px solid #999999;
border-right: 1px solid #999999;
border-bottom: 1px solid #999999;
border-left: 1px solid #999999;
padding-top: 0px;
padding-right: 0px;
padding-bottom: 0px;
padding-left: 0px;
overflow: hidden;
}
body {
margin-left: 5px;
margin-top: 5px;
margin-right: 0px;
margin-bottom: 10px;
table {
table-layout:fixed; 
border: thin solid #000000;
}
-->
</style>
</head>
<body>
<table width='1200'>
<tr bgcolor='#CCCCCC'>
<td colspan='7' height='48' align='center' valign="middle">
<font face='tahoma' color='#003399' size='4'>
<strong>$title - $date</strong></font>
</td>
</tr>
</table>
"@
$head | Out-File $fileName
}
# ==============================================================================================
Function writeTableHeader
{
param($fileName, $firstheaderName, $headerNames, $headerWidths, $tablewidth)
$tableHeader = @"
<table width='$tablewidth'><tbody>
<tr bgcolor=#CCCCCC>
<td width='6%' align='center'><strong>$firstheaderName</strong></td>
"@
$i = 0
while ($i -lt $headerNames.count) {
$headerName = $headerNames[$i]
$headerWidth = $headerWidths[$i]
$tableHeader += "<td width='" + $headerWidth + "%' align='center'><strong>$headerName</strong></td>"
$i++
}
$tableHeader += "</tr>"
$tableHeader | Out-File $fileName -append
}
# ==============================================================================================
Function writeTableFooter
{
param($fileName)
"</table><br/>"| Out-File $fileName -append
}
#==============================================================================================
Function writeData
{
param($data, $fileName, $headerNames)
  
 $data.Keys | sort | foreach {
$tableEntry += "<tr>"
$computerName = $_
$tableEntry += ("<td bgcolor='#CCCCCC' align=center><font color='#003399'>$computerName</font></td>")
#$data.$_.Keys | foreach {
$headerNames | foreach {
#"$computerName : $_" | LogMe -display
try {
if ($data.$computerName.$_[0] -eq "SUCCESS") { $bgcolor = "#387C44"; $fontColor = "#FFFFFF" }
elseif ($data.$computerName.$_[0] -eq "WARNING") { $bgcolor = "#FF7700"; $fontColor = "#FFFFFF" }
elseif ($data.$computerName.$_[0] -eq "ERROR") { $bgcolor = "#FF0000"; $fontColor = "#FFFFFF" }
else { $bgcolor = "#CCCCCC"; $fontColor = "#003399" }
$testResult = $data.$computerName.$_[1]
}
catch {
$bgcolor = "#CCCCCC"; $fontColor = "#003399"
$testResult = ""
}
  
 $tableEntry += ("<td bgcolor='" + $bgcolor + "' align=center><font color='" + $fontColor + "'>$testResult</font></td>")
}
  
 $tableEntry += "</tr>"
  
  
 }
  
 $tableEntry | Out-File $fileName -append
}
# ==============================================================================================
Function writeHtmlFooter
{
param($fileName)
@"
<table>
<table width='1200'>
<tr bgcolor='#CCCCCC'>
<td colspan='7' height='25' align='left'>
<br>
<font face='courier' color='#000000' size='2'><strong>Retry Threshold =</strong></font><font color='#003399' face='courier' size='2'> $retrythresholdWarning<tr></font><br>
<tr bgcolor='#CCCCCC'>
</td>
</tr>
<tr bgcolor='#CCCCCC'>
</tr>
</table>
</body>
</html>
"@ | Out-File $FileName -append
}
 
 function Farmcheck() {
# ======= PVS Farm Check ====================================================================
"Read some PVS Farm Parameters" | LogMe -display -progress
" " | LogMe -display -progress
$global:PVSFarmResults = @{}
$PVSfarm = Get-PVSFarm

$global:farmname_short = $PVSfarm.FarmName 
$PVSFarmtests = @{}

$DBServer = $PVSFarm | %{ $_.DatabaseServerName }
$PVSFarmtests.DBServerName = "NEUTRAL", $DBServer

$dbname = $PVSFarm | %{ $_.DatabaseName }
$PVSFarmtests.databaseName = "NEUTRAL", $dbname

$OfflineDB = $PVSFarm | %{ $_.OfflineDatabaseSupportEnabled }
$PVSFarmtests.OfflineDB = "NEUTRAL", $OfflineDB

$LicenseServer = $PVSFarm | %{ $_.LicenseServer }
$PVSFarmtests.LicenseServer = "NEUTRAL", $LicenseServer

$global:PVSFarmResults.$global:farmname_short = $PVSFarmtests
}

function PVSServerCheck() {
# ======= PVS Server Check ==================================================================
"Check PVS Servers" | LogMe -display -progress
" " | LogMe -display -progress
 
$global:PVSResults = @{}
$allPVSServer = Get-PvsServer

foreach($PVServerName in $allPVSServer){
$PVStests = @{}
  
$PVServerName_short = $PVServerName | %{ $_.ServerName }
"PVS-Server: $PVServerName_short" | LogMe -display -progress
$PVServerName_short

# Ping server 
$result = Ping $PVServerName_short 100
"Ping: $result" | LogMe -display -progress
if ($result -ne "SUCCESS") { $PVStests.Ping = "ERROR", $result }
else { $PVStests.Ping = "SUCCESS", $result 


# Check services
		if ((Get-Service -Name "soapserver" -ComputerName $PVServerName_short).Status -Match "Running") {
			"SoapService running..." | LogMe
			$PVStests.SoapService = "SUCCESS", "Success"
		} else {
			"SoapService service stopped"  | LogMe -display -error
			$PVStests.SoapService = "ERROR", "Error"
		}
			
		if ((Get-Service -Name "StreamService" -ComputerName $PVServerName_short).Status -Match "Running") {
			"StreamService service running..." | LogMe
			$PVStests.StreamService = "SUCCESS","Success"
		} else {
			"StreamService service stopped"  | LogMe -display -error
			$PVStests.StreamService = "ERROR","Error"
		}
			
		if ((Get-Service -Name "BNTFTP" -ComputerName $PVServerName_short).Status -Match "Running") {
			"TFTP service running..." | LogMe
			$PVStests.TFTPService = "SUCCESS","Success"
		} else {
			"TFTP  service stopped"  | LogMe -display -error
			$PVStests.TFTPService = "ERROR","Error"
		
 }
 
 
 #==============================================================================================
#               CHECK CPU AND MEMORY USAGE 
#==============================================================================================

        # Check the AvgCPU value for 5 seconds
        $AvgCPUval = CheckCpuUsage ($PVServerName_short)
		#$VDtests.LoadBalancingAlgorithm = "SUCCESS", "LB is set to BEST EFFORT"} 
			
        if( [int] $AvgCPUval -lt 75) { "CPU usage is normal [ $AvgCPUval % ]" | LogMe -display; $PVStests.AvgCPU = "SUCCESS", "$AvgCPUval %" }
		elseif([int] $AvgCPUval -lt 85) { "CPU usage is medium [ $AvgCPUval % ]" | LogMe -warning; $PVStests.AvgCPU = "WARNING", "$AvgCPUval %" }   	
		elseif([int] $AvgCPUval -lt 95) { "CPU usage is high [ $AvgCPUval % ]" | LogMe -error; $PVStests.AvgCPU = "ERROR", "$AvgCPUval %" }
		elseif([int] $AvgCPUval -eq 101) { "CPU usage test failed" | LogMe -error; $PVStests.AvgCPU = "ERROR", "Err" }
        else { "CPU usage is Critical [ $AvgCPUval % ]" | LogMe -error; $PVStests.AvgCPU = "ERROR", "$AvgCPUval %" }   
		$AvgCPUval = 0

        # Check the Physical Memory usage       
        $UsedMemory = CheckMemoryUsage ($PVServerName_short)
        if( $UsedMemory -lt 0.75) { "Memory usage is normal [ {0:p2} ]" -f $UsedMemory | LogMe -display; $PVStests.MemUsg = "SUCCESS", "{0:p2} ]" -f $UsedMemory }
		elseif($UsedMemory -lt 0.85) { "Memory usage is medium [ {0:p2} ]" -f $UsedMemory | LogMe -warning; $PVStests.MemUsg = "WARNING", "{0:p2} ]" -f $UsedMemory }   	
		elseif($UsedMemory -lt 0.95) { "Memory usage is high [ {0:p2} ]" -f $UsedMemory | LogMe -error; $PVStests.MemUsg = "ERROR", "{0:p2} ]" -f $UsedMemory }
		elseif($UsedMemory -eq 1.01) { "Memory usage test failed" | LogMe -error; $PVStests.MemUsg = "ERROR", "Err" }
        else { "Memory usage is Critical [ {0:p2} ]" -f $UsedMemory | LogMe -error; $PVStests.MemUsg = "ERROR", "{0:p2} ]" -f $UsedMemory }   
		$UsedMemory = 0  

        foreach ($disk in $diskLetters)
        {
            # Check Disk Usage 
            $HardDisk = Get-WmiObject Win32_LogicalDisk -ComputerName $PVServerName_short -Filter "DeviceID='$($disk):'" | Select-Object Size,FreeSpace 
            $DiskTotalSize = $HardDisk.Size 
            $DiskFreeSpace = $HardDisk.FreeSpace 
            $frSpace=[Math]::Round(($DiskFreeSpace/1073741824),2)

            $PercentageDS = (($DiskFreeSpace / $DiskTotalSize ) * 100); $PercentageDS = "{0:N2}" -f $PercentageDS 

            If ( [int] $PercentageDS -gt 15) { "Disk Free is normal [ $PercentageDS % ]" | LogMe -display; $PVStests."$($disk)Freespace" = "SUCCESS", "$frSpace GB" } 
		    ElseIf ([int] $PercentageDS -lt 15) { "Disk Free is Low [ $PercentageDS % ]" | LogMe -warning; $PVStests."$($disk)Freespace" = "WARNING", "$frSpace GB" }     
		    ElseIf ([int] $PercentageDS -lt 5) { "Disk Free is Critical [ $PercentageDS % ]" | LogMe -error; $PVStests."$($disk)Freespace" = "ERROR", "$frSpace GB" } 
		    ElseIf ([int] $PercentageDS -eq 0) { "Disk Free test failed" | LogMe -error; $PVStests."$($disk)Freespace" = "ERROR", "Err" } 
            Else { "Disk Free is Critical [ $PercentageDS % ]" | LogMe -error; $PVStests."$($disk)Freespace" = "ERROR", "$frSpace GB" }   
            $PercentageDS = 0   
        }


   
  
#Check PVS Activity Status (over PVS Framework)
$serverstatus = Get-PvsServerStatus -ServerName $PVServerName_short
$actviestatus = $serverstatus.Status
if ($actviestatus -eq 1) { $PVStests.Active = "SUCCESS", "active" }
else { $PVStests.Active = "Error","inactive" }
"PVS-Active-Status: $actviestatus" | LogMe -display -progress


  
#Check PVS deviceCount
$numberofdevices = $serverstatus.DeviceCount
if ($numberofdevices -ge 1) { $PVStests.deviceCount = "SUCCESS", " $numberofdevices active" }
else { $PVStests.deviceCount = "WARNING","No devices on this server" }
"Number of devices: $numberofdevices" | LogMe -display -progress

$global:PVSResults.$PVServerName_short = $PVStests
  
}
}
}


function PVSvDiskCheck() {
	# ======= PVS vDisk Check #==================================================================
	"Check PVS vDisks" | LogMe -display -progress
	" " | LogMe -display -progress
	
	$AllvDisks = Get-PvsDiskInfo -SiteName $siteName
	$global:vdiskResults = @{}
	
	foreach($vDisk in $AllvDisks )
		{
		$VDtests = @{}
		
		#VdiskName
		$vDiskName = $vDisk | %{ $_.Name }
		"Name of vDisk: $vDiskName" | LogMe -display -progress
		$vDiskName
    
        #VdiskSite
		$VdiskSite = $vDisk | %{ $_.sitename }
		"vDiskDtore: $VdiskSite" | LogMe -display -progress
		$VDtests.Site = "NEUTRAL", $VdiskSite
		
		#VdiskStore
		$vDiskStore = $vDisk | %{ $_.StoreName }
		"vDiskDtore: $vDiskStore" | LogMe -display -progress
		$VDtests.Store = "NEUTRAL", $vDiskStore

        
		
			#Get details of each version of the vDisk: 
			$vDiskVersions = Get-PvsDiskVersion -Name $vDiskName -SiteName $VdiskSite -StoreName $vDiskStore
			
			$vDiskVersionTable = @{}
			foreach($diskVersion in $vDiskVersions){
			
			#VdiskVersionFilename
			$diskversionfilename = $diskVersion | %{ $_.DiskFileName }
			"Filename of Version: $diskversionfilename" | LogMe -display -progress
			$vDiskVersionTable.diskversionfilename += $diskversionfilename +="<br>"
			
			#VdiskVersionVersion
			$diskversionDeviceCount = $diskVersion | %{ $_.DeviceCount }
			$StringDiskversionDeviceCount = $diskversionDeviceCount | Out-String
			"Version: $StringDiskversionDeviceCount" | LogMe -display -progress
			$vDiskVersionTable.StringDiskversionDeviceCount += $StringDiskversionDeviceCount +="<br>"
			
			#VdiskVersionCreateDate
			$diskversionCreateDate = $diskVersion | %{ $_.CreateDate }
			"Filename of Version: $diskversionCreateDate" | LogMe -display -progress
			$vDiskVersionTable.diskversionCreateDate += $diskversionCreateDate +="<br>"
			
			#VdiskVersion ReplState (GoodInventoryStatus)
			$diskversionGoodInventoryStatus = $diskVersion | %{ $_.GoodInventoryStatus }
			$StringDiskversionGoodInventoryStatus = $diskversionGoodInventoryStatus | Out-String
			"Filename of Version: $StringDiskversionGoodInventoryStatus" | LogMe -display -progress
			#Check if correct replicated, count Replication Errors
			Write-Host "Schreibe hier: " $DiskversionGoodInventoryStatus
			$ReplErrorCount = 0
			if($DiskversionGoodInventoryStatus -like "True" ){
			$ReplErrorCount += 0
			 } else {
			$ReplErrorCount += 1}
			$vDiskVersionTable.StringDiskversionGoodInventoryStatus += $StringDiskversionGoodInventoryStatus +="<br>"
			#Check if correct replicated THE LAST DISK
			if($ReplErrorCount -eq 0 ){
			"$diskversionfilename correct replicated" | LogMe
			$ReplStateStatus = "SUCCESS"
			 } else {
			"$diskversionfilename not correct replicated $ReplErrorCount errors" | LogMe -display -error
			$ReplStateStatus = "ERROR"}
			
			}
			
		$VDtests.vDiskFileName = "Neutral", $vDiskVersionTable.diskversionfilename
		$VDtests.DeviceCount = "Neutral", $vDiskVersionTable.StringDiskversionDeviceCount
		$VDtests.CreateDate = "Neutral", $vDiskVersionTable.diskversionCreateDate
		$VDtests.ReplState = "$ReplStateStatus", $vDiskVersionTable.StringDiskversionGoodInventoryStatus
			
			
	
		#Check for WriteCacheType
		# -----------------------
		# Feel free to change it to the the from you desired State (e.g.Exchange a SUCCESS with a WARNING)
		# In this default configuration, only "Cache to Ram with overflow" and "Cache to Device Hard disk" is desired and appears green on the output.
		#
		#  $WriteCacheType 9=RamOfToHD 0=PrivateMode 4=DeviceHD 8=DeviceHDPersistent 3=DeviceRAM 1=PVSServer 7=ServerPersistent 
		 
		$vDiskWriteCacheType = $vDisk | %{ $_.WriteCacheType }
		
		 if($vDiskWriteCacheType -eq 9 ){
		"WC is set to Cache to Device Ram with overflow to HD" | LogMe
		$VDtests.WriteCacheType = "SUCCESS", "WC Cache to Ram with overflow to HD"}
		  
		 elseif($vDiskWriteCacheType -eq 0 ){
		"WC is not set because vDisk is in PrivateMode (R/W)" | LogMe
		$VDtests.WriteCacheType = "Error", "vDisk is in PrivateMode (R/W) "}
		  
		 elseif($vDiskWriteCacheType -eq 4 ){
		"WC is set to Cache to Device Hard Disk" | LogMe
		$VDtests.WriteCacheType = "SUCCESS", "WC is set to Cache to Device Hard Disk"}
		  
		 elseif($vDiskWriteCacheType -eq 8 ){
		"WC is set to Cache to Device Hard Disk Persistent" | LogMe
		$VDtests.WriteCacheType = "Error", "WC is set to Cache to Device Hard Disk Persistent"}
		  
		 elseif($vDiskWriteCacheType -eq 3 ){
		"WC is set to Cache to Device Ram" | LogMe
		$VDtests.WriteCacheType = "WARNING", "WC is set to Cache to Device Ram"}
		  
		 elseif($vDiskWriteCacheType -eq 1 ){
		"WC is set to Cache to PVS Server HD" | LogMe
		$VDtests.WriteCacheType = "Error", "WC is set to Cache to PVS Server HD"}
		  
		 elseif($vDiskWriteCacheType -eq 7 ){
		"WC is set to Cache to PVS Server HD Persistent" | LogMe
		$VDtests.WriteCacheType = "Error", "WC is set to Cache to PVS Server HD Persistent"}
		
		
		#Vdisk SubnetAffinity or fixed ServerName
		$vDiskfixServerName = $vDisk | %{ $_.ServerName }
		"vDisk is fix assigned to Server: $vDiskfixServerName" | LogMe -display -progress
		if($vDiskfixServerName -eq "" )
			{
			$vDiskSubnetAffinity = $vDisk | %{ $_.SubnetAffinity }
			"vDiskDtore: $vDiskSubnetAffinity" | LogMe -display -progress
			
			#SubnetAffinity: 1=Best Effort, 2= fixed, 0=none
			if($vDiskSubnetAffinity -eq 1 ){
			"LB-Algorythm is set to BestEffort" | LogMe
			$VDtests.LoadBalancingAlgorithm = "SUCCESS", "LB is set to BEST EFFORT"} 
			  
			 elseif($vDiskSubnetAffinity -eq 2 ){
			"LB-Algorythm is set to fixed" | LogMe
			$VDtests.LoadBalancingAlgorithm = "WARNING", "LB is set to FIXED"}
			  
			 elseif($vDiskSubnetAffinity -eq 0 ){
			"LB-Algorythm is set to none" | LogMe
			$VDtests.LoadBalancingAlgorithm = "SUCCESS", "LB is set to NONE, least busy server is used"}
			}
			
			else{
			$VDtests.LoadBalancingAlgorithm = "ERROR", "No LoadBalancing! Server is fix assigned to $vDiskfixServerName"}
			
            #image name adds Site name in multi site reports
            if ($siteName.count -ne 1) {$global:vdiskResults."$vDiskName ($VdiskSite)" = $VDtests}
            else {$global:vdiskResults.$vDiskName = $VDtests}

		}
	

}

function PVSTargetCheck() {
# ======= PVS Target Device Check ========
"Check PVS Target Devices" | LogMe -display -progress
" " | LogMe -display -progress

$global:allResults = @{}
$pvsdevices = Get-PvsDevice

foreach($target in $pvsdevices) {
$tests = @{} 
	
	# Check to see if the server is in an excluded folder path
	$CollectionName = $target | %{ $_.CollectionName }
  
		#Only Check Servers in defined Collections: 
		if ($Collections -contains $CollectionName -Or $Collections -contains "every") { 
	
	
		$targetName = $target | %{ $_.Name }
		
		$targetName
		
		#Name of CollectionName
		$CollectionName = $target | %{ $_.CollectionName }
		"Collection: $CollectionName" | LogMe -display -progress
		$tests.CollectionName = "NEUTRAL", "$CollectionName"
		
		$targetNamePvsDeviceInfo = Get-PvsDeviceInfo -Name $targetName
		
		
		$DeviceUsedDiskVersion = $targetNamePvsDeviceInfo.DiskVersion
		"Used DiskVersion: $DeviceUsedDiskVersion" | LogMe -display -progress
		$tests.vDisk_Version = "NEUTRAL", "$DeviceUsedDiskVersion"
		
		$DeviceUsedServerName= $targetNamePvsDeviceInfo.ServerName
		"Used Server: $DeviceUsedServerName" | LogMe -display -progress
		$tests.PVSServer = "NEUTRAL", "$DeviceUsedServerName"
		
		$targetNamePvsDeviceStatus = Get-PvsDeviceStatus -Name $targetName
		
		$RetryStatus = $targetNamePvsDeviceStatus.Status
		"Retry: $RetryStatus" | LogMe -display -progress
		$tests.Retry = "NEUTRAL", "$RetryStatus"
		
		 # Ping target 
		$result = Ping $targetName 100
		if ($result -ne "SUCCESS") { $tests.Ping = "ERROR", $result }
		else { $tests.Ping = "SUCCESS", $result 
		}

		$DiskFileNameStatus = $targetNamePvsDeviceStatus.DiskFileName
		"Retry: $DiskFileNameStatus" | LogMe -display -progress
		$tests.vDisk_PVS = "NEUTRAL", "$DiskFileNameStatus"
	

		################ PVS WriteCache SECTION ###############	
		$short_diskLocatorID = $targetNamePvsDeviceInfo.DiskLocatorId
		$diskinfo = Get-PvsDiskInfo -DiskLocatorId $short_diskLocatorID
		$short_DeviceWriteCacheType = $diskinfo.WriteCacheType
		
		if (test-path \\$targetName\c$\Personality.ini) #checks if Personality file is present and accessible and then checks 3 WCtypes
		#if ($short_DeviceWriteCacheType -eq "4")
		{

			$wconhd = ""
			
			#$job = Start-Job { #Job-Created but never received
			$wconhd = Get-Content \\$targetName\c$\Personality.ini | Where-Object  {$_.Contains("WriteCacheType") }
			#}
			#$res = Wait-Job $job -timeout 3
			#if(-not $res) {Write-Host "Timeout"}

			
			If ($wconhd -eq '$WriteCacheType=4')
			{Write-Host Cache on HDD
			
			#WWC on HD is $wconhd

				# Relative path to the PVS vDisk write cache file
				$PvsWriteCache   = "d$\.vdiskcache"
				# Size of the local PVS write cache drive
				$PvsWriteMaxSize = 10gb # size in GB
			
				$PvsWriteCacheUNC = Join-Path "\\$targetName" $PvsWriteCache 
				$CacheDiskexists  = Test-Path $PvsWriteCacheUNC
				if ($CacheDiskexists -eq $True)
				{
					$CacheDisk = [long] ((get-childitem $PvsWriteCacheUNC -force).length)
					$CacheDiskGB = "{0:n2}GB" -f($CacheDisk / 1GB)
					"PVS Cache file size: {0:n2}GB" -f($CacheDisk / 1GB) | LogMe
					#"PVS Cache max size: {0:n2}GB" -f($PvsWriteMaxSize / 1GB) | LogMe -display
					if($CacheDisk -lt ($PvsWriteMaxSize * 0.5))
					{
					   "WriteCache file size is low" | LogMe
					   $tests.WriteCache = "SUCCESS", $CacheDiskGB
					}
					elseif($CacheDisk -lt ($PvsWriteMaxSize * 0.8))
					{
					   "WriteCache file size moderate" | LogMe -display -warning
					   $tests.WriteCache = "WARNING", $CacheDiskGB
					}   
					else
					{
					   "WriteCache file size is high" | LogMe -display -error
					   $tests.WriteCache = "ERORR", $CacheDiskGB
					}
				}              
			   
				$Cachedisk = 0
			   
				$VDISKImage = get-content \\$targetName\c$\Personality.ini | Select-String "Diskname" | Out-String | % { $_.substring(12)}
				if($VDISKImage -Match $DefaultVDISK){
					"Default vDisk detected" | LogMe
					$tests.vDisk = "SUCCESS", $VDISKImage
				} else {
					"vDisk unknown"  | LogMe -display -error
					$tests.vDisk = "SUCCESS", $VDISKImage
				}   
			
			}
			elseif ($wconhd -eq '$WriteCacheType=9')
            		{
            			Write-Host Cache on RAM with overflow
				#RAMCache
				#Get-RamCache from each target, code from Matthew Nics http://mattnics.com/?p=414
				$RAMCache = [math]::truncate((Get-WmiObject Win32_PerfFormattedData_PerfOS_Memory -ComputerName $targetName).PoolNonPagedBytes /1MB)
			
            			# Relative path to the PVS vDisk write cache file
				$PvsWriteCache   = "d$\vdiskdif.vhdx"
				# Size of the local PVS write cache drive
				$PvsWriteMaxSize = 10gb # size in GB
			
				$PvsWriteCacheUNC = Join-Path "\\$targetName" $PvsWriteCache 
				$CacheDiskexists  = Test-Path $PvsWriteCacheUNC
				if ($CacheDiskexists -eq $True)
				{
					$CacheDisk = [long] ((get-childitem $PvsWriteCacheUNC -force).length)
					$CacheDiskGB = "{0:n2} GB" -f($CacheDisk / 1GB)
					"PVS Cache file size: {0:n2} GB" -f($CacheDisk / 1GB) | LogMe
					#"PVS Cache max size: {0:n2}GB" -f($PvsWriteMaxSize / 1GB) | LogMe -display
					if($CacheDisk -lt ($PvsWriteMaxSize * 0.5))
					{
					   "WriteCache file size is low" | LogMe
					   $tests.WriteCache = "SUCCESS", $CacheDiskGB
					}
					elseif($CacheDisk -lt ($PvsWriteMaxSize * 0.8))
					{
					   "WriteCache file size moderate" | LogMe -display -warning
					   $HDDwarning = $true
					   $tests.WriteCache = "WARNING", $CacheDiskGB
					}   
					else
					{
					   "WriteCache file size is high" | LogMe -display -error
                        		   $HDDerror = $true
					   $tests.WriteCache = "ERORR", $CacheDiskGB
					}
				}              
			   
				$Cachedisk = 0
			   
				$VDISKImage = get-content \\$targetName\c$\Personality.ini | Select-String "Diskname" | Out-String | % { $_.substring(12)}
				if($VDISKImage -Match $DefaultVDISK){
					"Default vDisk detected" | LogMe
					$tests.vDisk = "SUCCESS", $VDISKImage
				} else {
					"vDisk unknown"  | LogMe -display -error
					$tests.vDisk = "SUCCESS", $VDISKImage
				}  

                #merge HDD and RAM data
                if ($HDDwarning)
                {$tests.WriteCache = "WARNING", "$CacheDiskGB, $RamCache MB on Ram"}
                elseif ($HDDerror)
                {$tests.WriteCache = "ERORR", "$CacheDiskGB, $RamCache MB on Ram"}
                else
                {$tests.WriteCache = "SUCCESS", "$CacheDiskGB, $RamCache MB on Ram"}
                 


            }
			elseif ($wconhd -eq '$WriteCacheType=3')
			{Write-Host Cache on Ram
			
			#RAMCache
			#Get-RamCache from each target, code from Matthew Nics http://mattnics.com/?p=414
			$RAMCache = [math]::truncate((Get-WmiObject Win32_PerfFormattedData_PerfOS_Memory -ComputerName $targetName).PoolNonPagedBytes /1MB)
			$tests.WriteCache = "Neutral", "$RamCache MB on Ram"
		
			}
			else
			{
			Write-Host Cache on Ram
			$tests.WriteCache = "WARNING", "Other WriteCache Type"
			}
		
		}
		else 
		{Write-Host WriteCache not readable
		$tests.WriteCache = "Neutral", "Cache not readable"	
		}
		############## END PVS WriteCache SECTION #############
	


	$global:allResults.$targetName = $tests
	}
}
 
 
 
 }


#==============================================================================================
#HTML function
function WriteHTML() {
 
    # ======= Write all results to an html file =================================================
    Write-Host ("Saving results to html report: " + $resultsHTM)
    # STBE writeHtmlHeader "PVS Farm Report $global:farmname_short" $resultsHTM
    #$EnvironmentName = "$EnvironmentName $global:farmname_short"
    writeHtmlHeader "$EnvName" $resultsHTM

    if ($PerformPVSvDiskCheck -eq "yes") {
    writeTableHeader $resultsHTM $vDiksFirstheaderName $vDiskheaderNames $vDiskheaderWidths $vDisktablewidth
    $global:vdiskResults | sort-object -property ReplState | % { writeData $vdiskResults $resultsHTM $vDiskheaderNames }
    writeTableFooter $resultsHTM
    }

    writeTableHeader $resultsHTM $PVSFirstheaderName $PVSheaderNames $PVSheaderWidths $PVStablewidth
    $global:PVSResults | sort-object -property PVServerName_short | % { writeData $PVSResults $resultsHTM $PVSheaderNames}
    writeTableFooter $resultsHTM
 
    writeTableHeader $resultsHTM $PVSFirstFarmheaderName $PVSFarmHeaderNames $PVSFarmWidths $PVSFarmTablewidth
    $global:PVSFarmResults | % { writeData $PVSFarmResults $resultsHTM $PVSFarmHeaderNames}
    writeTableFooter $resultsHTM

    if ($PerformPVSTargetCheck -eq "yes") {
    writeTableHeader $resultsHTM $TargetFirstheaderName $TargetheaderNames $TargetheaderWidths $TargetTablewidth
    $allResults | sort-object -property collectionName | % { writeData $allResults $resultsHTM $TargetheaderNames}
    writeTableFooter $resultsHTM
    }

    writeHtmlFooter $resultsHTM
# STBE    #send email
# STBE    $emailSubject = ("$emailSubjectStart - $global:farmname_short - " + (Get-Date -format R))
# STBE    $global:mailMessageParameters = @{
# STBE        From = $emailFrom
# STBE        To = $emailTo
# STBE        Subject = $emailSubject
# STBE        SmtpServer = $smtpServer
# STBE        Body = (gc $resultsHTM) | Out-String
# STBE        Attachment = $resultsHTM
# STBE    }
}
#==============================================================================================
#Mail function
# Send mail 
function SendMail() {
    Param (
        [Parameter(
            Mandatory = $True,
            Position = 0,
            ValueFromPipeline = $True
        )]
        [System.String[]]
        $Subject
    )
    #send email
    $emailMessage = New-Object System.Net.Mail.MailMessage
    $emailMessage.From = $emailFrom
    $emailMessage.To.Add( $emailTo )
    $emailMessage.Subject = $Subject
    $emailMessage.IsBodyHtml = $true
    $emailMessage.Body = (gc $resultsHTM) | Out-String
    $emailMessage.Attachments.Add($resultsHTM)
    $emailMessage.Priority = ($emailPrio)

    $smtpClient = New-Object System.Net.Mail.SmtpClient( $smtpServer , $smtpServerPort )
    $smtpClient.EnableSsl = $smtpEnableSSL

    # If you added username an password, add this to smtpClient
    If ((![string]::IsNullOrEmpty($smtpUser)) -and (![string]::IsNullOrEmpty($smtpPW))){
	    $pass = $smtpPW | ConvertTo-SecureString -key $smtpKey
	    $cred = New-Object System.Management.Automation.PsCredential($smtpUser,$pass)

	    $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($cred.Password)
	    $smtpUserName = $cred.Username
	    $smtpPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)

	    $smtpClient.Credentials = New-Object System.Net.NetworkCredential( $smtpUserName , $smtpPassword );
    }

    $smtpClient.Send( $emailMessage )
}


#==============================================================================================
# == MAIN SCRIPT ==
#==============================================================================================
$scriptstart = Get-Date
rm $logfile -force -EA SilentlyContinue
"Begin with Citrix Provisioning Services HealthCheck" | LogMe -display -progress
" " | LogMe -display -progress

Farmcheck
$EnvName = "$EnvironmentName $farmname_short"
$emailSubject = ("$EnvName - " + $ReportDate)
 
if ($PerformPVSTargetCheck -eq "yes") {
"Initiate PVS Target check" | LogMe
PVSTargetCheck
} else {
" PVS Target check skipped" | LogMe
}

if ($PerformPVSvDiskCheck -eq "yes") {
"Initiate PVS Target check" | LogMe
PVSvDiskCheck
} else {
" PVSvDiskCheck check skipped" | LogMe
}

PVSServerCheck
WriteHTML


if ($PerformSendMail -eq "yes") {
"Initiate send of Email " | LogMe
SendMail -Subject $emailSubject
} else {
"send of Email  skipped" | LogMe
}

$scriptend = Get-Date
$scriptruntime =  $scriptend - $scriptstart | select TotalSeconds
$scriptruntimeInSeconds = $scriptruntime.TotalSeconds
#Write-Host $scriptruntime.TotalSeconds
"Script was running for $scriptruntimeInSeconds " | LogMe -display -progress
