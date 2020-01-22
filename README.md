# citrix-pvs-healthcheck
Citrix PVS Healthcheck 

If you are Using PVS 1909 or a newer Version you need <b>Citrix-PVS-Farm-Health-toHTML.ps1</b> and <b>Citrix-PVS-Farm-Health-toHTML_Parameters.xml</b>
<br>
for PVS 7.7 until 1906 (7.22) you need <b>Citrix-PVS77-Farm-Health-toHTML.ps1</b> and <b>Citrix-PVS77-Farm-Health-toHTML_Parameters.xml</b>
<br>
for even older PVS Version (7.6 and below) use the Script here: http://blog.sachathomet.ch/citrix-pvs-healthcheck


Prerequisite: Script must run on a PVS server, where PVS snap-in is registered with this command:
 1. set-alias installutil C:\Windows\Microsoft.NET\Framework64\v4.0.30319\installutil.exe
 2. installutil "C:\Program Files\Citrix\Provisioning Services Console\Citrix.PVS.SnapIn.dll"
 3. Add-PSSnapin Citrix*
