


#Root of all Member Server Resources
$resRoot = "Test Resources"

#Member Server OU's Name
$memSrvRoot = "Member Servers"

#Restricted Groups OU Name
$ResGroupRoot = "Restricted Groups"

#List of Server or Applications Services
$srvService = "Exchange","SCCM","SCOM","VMM","File","SharePoint","DHCP"

$getMSRoot = Get-ADOrganizationalUnit -filter * | where {$_.DistinguishedName -like "*$MemSrvRoot*"} | Select-Object -Skip 1

if ($getMSRoot -eq $null)
{
    $rootDSE = (Get-ADRootDSE).rootDomainNamingContext

    New-ADOrganizationalUnit -Name $resRoot

    $resourceOU = "OU=" + "$resRoot" + "," + "$rootDSE"
    $memSrvOU = "OU=" + "$memSrvRoot" + ",OU=" + "$resRoot" + "," + "$rootDSE"

    New-ADOrganizationalUnit -name $memSrvRoot -Path $resourceOU
    New-ADOrganizationalUnit -name $ResGroupRoot -Path $resourceOU

        Foreach ($svc in $srvService )
        {
            New-ADOrganizationalUnit -name $svc -Path $memSrvOU
        }
}

$getOUMS = Get-ADOrganizationalUnit -Filter * | where {$_.DistinguishedName -like "*$resourceOU*" -and $_.Name -ne "$resRoot" -and $_.Name -ne "$ResGroupRoot"   -and $_.Name -eq "$memSrvRoot"} 
$getOU = Get-ADOrganizationalUnit -Filter * | where {$_.DistinguishedName -like "*$resourceOU*" -and $_.Name -ne "$resRoot" -and $_.Name -ne "$ResGroupRoot"}

#OU to create Restricted Groups
$getOURG = ((Get-ADOrganizationalUnit -Filter * | where {$_.DistinguishedName -like "*$resourceOU*" -and $_.Name -ne "$resRoot" -and $_.Name -eq "$ResGroupRoot"}).DistinguishedName) #| Select-Object -Skip 1

#One Group to Rule them all - Top OU Level Admin Group that has Admin rights on all Sub-OU Servers
#Root Admin Group Name
$rgRtAdminGp = "RG_" + $MemSrvRoot + "_Admin"
#Root RDP Group Name
$rgRtRDPGp = "RG_" + $MemSrvRoot + "_RDP"

#Admin Group Description
$rgRtAdminDescrip = "Members of this group have Administrator privileges on all Servers in sub-Ou's"
#RDP Group Description
$rgRtRDPDescrip = "Members of this group have Remote Desktop privileges on all Servers in sub-Ou's"

New-ADGroup -Name $rgRtAdminGp –groupscope Global -Path $getOURG -Description $rgRtAdminDescrip
New-ADGroup -Name $rgRtRDPGp –groupscope Global -Path $getOURG -Description $rgRtRDPDescrip

#Get New Group Name and SID
$getRtRGAdmin = Get-ADGroup $rgRtAdminGp
$getRtRGRDP = Get-ADGroup $rgRtRDPGp

$getRtRGAdminSid = $getRtRGAdmin.SID.Value
$getRtRGRDPSid = $getRtRGRDP.SID.Value

#GPO Name
$GPOName = "GPO_" + $MemSrvRoot + "_RestrictedGroup"

#New GPO based on the service and linked to OU
New-GPO -Name $GPOName | New-GPLink -Target $getOUMS.DistinguishedName

$getGpoId = (Get-GPO $GPOName).id
$getGPOPath = (Get-GPO $GPOName).path

$sysvol = "C:\Windows\SYSVOL\domain\Policies\" + "{" + $getGpoId + "}" + "\Machine\Microsoft\Windows NT\SecEdit"

New-Item -Path $sysvol -ItemType Directory -Force
New-Item -Path $sysvol -Name GptTmpl.inf -ItemType File -Force

$gptFile = $sysvol + "\GptTmpl.inf"

#S-1-5-32-544 = Administrator Group
#S-1-5-32-555 = Remote Desktop Group
#SeRemoteInteractiveLogonRight = Allow log on through Remote Desktop Services

#Admin Group Sids for Restricted Groups
$addConAdmin = "*S-1-5-32-544__Members = " + "*" + $getRtRGAdminSid
#RDP Group Sids for Restricted Groups
$addConRDP = "*S-1-5-32-555__Members = "+ "*" + $getRtRGRDPSid 

#User Rights Assignments
$addConURARemote = "SeRemoteInteractiveLogonRight = " + "*" + $getRtRGAdminSid + ",*" + $getRtRGRDPSid 

#Update GmpTmpl.inf with URA and Restricted Groups
Add-Content -Path $gptFile -Value '[Unicode]'
Add-Content -Path $gptFile -Value 'Unicode=yes'
Add-Content -Path $gptFile -Value '[Version]'
Add-Content -Path $gptFile -Value 'signature="$CHICAGO$"'
Add-Content -Path $gptFile -Value 'Revision=1'
Add-Content -Path $gptFile -Value '[Group Membership]'
Add-Content -Path $gptFile -Value '*S-1-5-32-544__Memberof ='
Add-Content -Path $gptFile -Value $addConAdmin 
Add-Content -Path $gptFile -Value '*S-1-5-32-555__Memberof ='
Add-Content -Path $gptFile -Value $addConRDP 
Add-Content -Path $gptFile -Value '[Privilege Rights]'
Add-Content -Path $gptFile -Value $addConURARemote    

Set-ADObject -Identity $getGPOPath -Replace @{gPCMachineExtensionNames="[{827D319E-6EAC-11D2-A4EA-00C04F79F83A}{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}]"}

Foreach ($ouItem in $getOU)
{
    $ouName = $ouItem.Name
    $ouDN = $ouItem.DistinguishedName

    $Mem_SrvRoot = $MemSrvRoot.Replace(" ","_")

    if ($ouName -ne "$memSrvRoot")
    {
        #Admin Group Name
        $rgAdminGp = "RG_" +  $Mem_SrvRoot+ "_"+ "$ouName" + "_Admin"
        #RDP Group Name
        $rgRDPGp = "RG_" +  $Mem_SrvRoot + "_"+ "$ouName" + "_RDP"

        #Admin Group Description
        $rgAdminDescrip = "Members of this group have Administrator privileges on the $ouName Servers"
        #RDP Group Description
        $rgRDPDescrip = "Members of this group have Remote Desktop privileges on the $ouName Servers"

        New-ADGroup -Name $rgAdminGp –groupscope Global -Path $getOURG -Description $rgAdminDescrip
        New-ADGroup -Name $rgRDPGp –groupscope Global -Path $getOURG -Description $rgRDPDescrip

        #Get New Group Name and SID
        $getRGAdmin = Get-ADGroup $rgAdminGp
        $getRGRDP = Get-ADGroup $rgRDPGp

        $getRGAdminSid = $getRGAdmin.SID.Value
        $getRGRDPSid = $getRGRDP.SID.Value

        #GPO Name
        $GPOName = "GPO_" +  $Mem_SrvRoot + "_"+ "$ouName" + "_RestrictedGroup"

        #New GPO based on the service and linked to OU
        New-GPO -Name $GPOName | New-GPLink -Target $ouDN 

        $getGpoId = (Get-GPO $GPOName).id 
        $getGPOPath = (Get-GPO $GPOName).path

        $sysvol = "C:\Windows\SYSVOL\domain\Policies\" + "{" + $getGpoId + "}" + "\Machine\Microsoft\Windows NT\SecEdit"

        New-Item -Path $sysvol -ItemType Directory -Force
        New-Item -Path $sysvol -Name GptTmpl.inf -ItemType File -Force

        $gptFile = $sysvol + "\GptTmpl.inf"

        #S-1-5-32-544 = Administrator Group
        #S-1-5-32-555 = Remote Desktop Group
        #SeRemoteInteractiveLogonRight = Allow log on through Remote Desktop Services

        #Admin Group Sids for Restricted Groups
        $addConAdmin = "*S-1-5-32-544__Members = " + "*" + $getRtRGAdminSid + "," + "*" + $getRGAdminSid
        #RDP Group Sids for Restricted Groups
        $addConRDP = "*S-1-5-32-555__Members = "+ "*" + $getRtRGRDPSid + "," + "*" + $getRGRDPSid

        #User Rights Assignments
        $addConURARemote = "SeRemoteInteractiveLogonRight = " + "*" + $getRtRGAdminSid + "," + "*" + $getRGAdminSid + "," + "*" + $getRtRGRDPSid + "," + "*" + $getRGRDPSid

        #Update GmpTmpl.inf with URA and Restricted Groups
        Add-Content -Path $gptFile -Value '[Unicode]'
        Add-Content -Path $gptFile -Value 'Unicode=yes'
        Add-Content -Path $gptFile -Value '[Version]'
        Add-Content -Path $gptFile -Value 'signature="$CHICAGO$"'
        Add-Content -Path $gptFile -Value 'Revision=1'
        Add-Content -Path $gptFile -Value '[Group Membership]'
        Add-Content -Path $gptFile -Value '*S-1-5-32-544__Memberof ='
        Add-Content -Path $gptFile -Value $addConAdmin 
        Add-Content -Path $gptFile -Value '*S-1-5-32-555__Memberof ='
        Add-Content -Path $gptFile -Value $addConRDP 
        Add-Content -Path $gptFile -Value '[Privilege Rights]'
        Add-Content -Path $gptFile -Value $addConURARemote

        #Set GPMC Machine Extensions so Manual Intervention is both displayed in GPO Management and applies to target 
        Set-ADObject -Identity $getGPOPath -Replace @{gPCMachineExtensionNames="[{827D319E-6EAC-11D2-A4EA-00C04F79F83A}{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}]"}

    }

}


