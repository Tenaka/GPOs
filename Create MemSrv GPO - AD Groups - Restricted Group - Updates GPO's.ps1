#Root of the domain
$rootDSE = (Get-ADRootDSE).rootDomainNamingContext

#Path to Sysvol
$smbSysvol = ((Get-SmbShare -name "sysvol").path).replace("SYSVOL\sysvol","sysvol")

#Root of all Member Server Resources
$resRoot = "Testing Resources"

#Member Server OU's Name
$memSrvRoot = "Member Servers"

#Restricted Groups OU Name
$ResGroupRoot = "Restricted Groups"

#List of Server or Applications Services
$srvService = "Exchange","SCCM","SCOM","VMM","File","SharePoint","DHCP"

$resourceOU = "OU=$($resRoot),$($rootDSE)"
$memSrvOU = "OU=$($memSrvRoot),OU=$($resRoot),$($rootDSE)"
$ResGroupOU = "OU=$($ResGroupRoot),OU=$($resRoot),$($rootDSE)" 

$getMSRoot=@()
$getMSRoot = Get-ADOrganizationalUnit -filter * | where {$_.DistinguishedName -eq $resourceOU } #| Select-Object -Skip 1

if ($getMSRoot.DistinguishedName -eq $null)
{
    New-ADOrganizationalUnit -Name $resRoot #-ProtectedFromAccidentalDeletion $false
    New-ADOrganizationalUnit -name $memSrvRoot -Path $resourceOU #-ProtectedFromAccidentalDeletion $false
    New-ADOrganizationalUnit -name $ResGroupRoot -Path $resourceOU #-ProtectedFromAccidentalDeletion $false

        Foreach ($svc in $srvService)
        {
           New-ADOrganizationalUnit -name $svc -Path $memSrvOU #-ProtectedFromAccidentalDeletion $false
        }
}

$getOUMS = Get-ADOrganizationalUnit -Filter * | where {$_.DistinguishedName -eq $memSrvOU} 
$getOU = Get-ADOrganizationalUnit -Filter * | where {$_.DistinguishedName -like "*$memSrvOU*" -and $_.DistinguishedName -ne $memSrvOU}

#One Group to Rule them all - Top OU Level Admin Group that has Admin rights on all Sub-OU Servers
#Root Admin Group Name
$rgRtAdminGp = "RG_$($MemSrvRoot)_Admin"
#Root RDP Group Name
$rgRtRDPGp = "RG_$($MemSrvRoot)_RDP"

#Admin Group Description
$rgRtAdminDescrip = "Members of this group have Administrator privileges on all Servers in sub-Ou's"
#RDP Group Description
$rgRtRDPDescrip = "Members of this group have Remote Desktop privileges on all Servers in sub-Ou's"

New-ADGroup -Name $rgRtAdminGp –groupscope Global -Path $ResGroupOU -Description $rgRtAdminDescrip
New-ADGroup -Name $rgRtRDPGp –groupscope Global -Path $ResGroupOU -Description $rgRtRDPDescrip

#Get New Group Name and SID
$getRtRGAdmin = Get-ADGroup $rgRtAdminGp
$getRtRGRDP = Get-ADGroup $rgRtRDPGp

$getRtRGAdminSid = $getRtRGAdmin.SID.Value
$getRtRGRDPSid = $getRtRGRDP.SID.Value

#GPO Name
$GPOName = "GPO_$($MemSrvRoot)_RestrictedGroup"

#New GPO based on the service and linked to OU
New-GPO -Name $GPOName | New-GPLink -Target $getOUMS.DistinguishedName

$getGpoId = (Get-GPO $GPOName).id
$getGPOPath = (Get-GPO $GPOName).path

Set-GPPermission -Guid $getGpoId -PermissionLevel GpoEditDeleteModifySecurity -TargetType Group -TargetName $rgAdminGp

$sysvol = "$($smbSysvol)\domain\Policies\{$($getGpoId)}\Machine\Microsoft\Windows NT\SecEdit"

#FabianNiesen supplied fix so GPO is versioned to 1 and not set to 0 (zero)
$gpt = "$($smbSysvol)\domain\Policies\{$($getGpoId)}\GPT.ini"
Set-content $gpt -Value "[General]"
Add-Content $gpt -Value "Version=1" 

New-Item -Path $sysvol -ItemType Directory -Force
New-Item -Path $sysvol -Name GptTmpl.inf -ItemType File -Force

$gptFile = "$($sysvol)\GptTmpl.inf"

#S-1-5-32-544 = Administrator Group
#S-1-5-32-555 = Remote Desktop Group
#SeRemoteInteractiveLogonRight = Allow log on through Remote Desktop Services

#Admin Group Sids for Restricted Groups
$addConAdmin = "*S-1-5-32-544__Members = *$($getRtRGAdminSid)"
#RDP Group Sids for Restricted Groups
$addConRDP = "*S-1-5-32-555__Members = *$($getRtRGRDPSid)" 

#User Rights Assignments
$addConURARemote = "SeRemoteInteractiveLogonRight = *$($getRtRGAdminSid),*$($getRtRGRDPSid)" 

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
#FabianNiesen supplied fix so GPO is versionedto 1 and not set to 0 (zero)
Set-ADObject -Identity $getGPOPath -Replace @{versionNumber="1"}

    Foreach ($ouItem in $getOU)
    {
        $ouName = $ouItem.Name
        $ouDN = $ouItem.DistinguishedName

        $Mem_SrvRoot = $MemSrvRoot.Replace(" ","_")
    
        #Admin Group Name
        $rgAdminGp = "RG_$($Mem_SrvRoot)_$($ouName)_Admin"
        #RDP Group Name
        $rgRDPGp = "RG_$($Mem_SrvRoot)_$($ouName)_RDP"

        #Admin Group Description
        $rgAdminDescrip = "Members of this group have Administrator privileges on the $ouName Servers"
        #RDP Group Description
        $rgRDPDescrip = "Members of this group have Remote Desktop privileges on the $ouName Servers"

        New-ADGroup -Name $rgAdminGp –groupscope Global -Path $ResGroupOU -Description $rgAdminDescrip
        New-ADGroup -Name $rgRDPGp –groupscope Global -Path $ResGroupOU -Description $rgRDPDescrip

        #Get New Group Name and SID
        $getRGAdmin = Get-ADGroup $rgAdminGp
        $getRGRDP = Get-ADGroup $rgRDPGp

        $getRGAdminSid = $getRGAdmin.SID.Value
        $getRGRDPSid = $getRGRDP.SID.Value

        #GPO Name
        $GPOName = "GPO_$($Mem_SrvRoot)_$($ouName)_RestrictedGroup"

        #New GPO based on the service and linked to OU
        New-GPO -Name $GPOName | New-GPLink -Target $ouDN 

        $getGpoId = (Get-GPO $GPOName).id 
        $getGPOPath = (Get-GPO $GPOName).path

        Set-GPPermission -Guid $getGpoId -PermissionLevel GpoEditDeleteModifySecurity -TargetType Group -TargetName $rgAdminGp

        $sysvol = "$($smbSysvol)\domain\Policies\{$($getGpoId)}\Machine\Microsoft\Windows NT\SecEdit"
        #FabianNiesen supplied fix so GPO is versioned to 1 and not set to 0 (zero)
        $gpt = "$($smbSysvol)\domain\Policies\{$($getGpoId)}\GPT.ini"
        Set-content $gpt -Value "[General]"
        Add-Content $gpt -Value "Version=1"

        New-Item -Path $sysvol -ItemType Directory -Force
        New-Item -Path $sysvol -Name GptTmpl.inf -ItemType File -Force

        $gptFile = $sysvol + "\GptTmpl.inf"

        #S-1-5-32-544 = Administrator Group
        #S-1-5-32-555 = Remote Desktop Group
        #SeRemoteInteractiveLogonRight = Allow log on through Remote Desktop Services

        #Admin Group Sids for Restricted Groups
        $addConAdmin = "*S-1-5-32-544__Members = *$($getRtRGAdminSid),*$($getRGAdminSid)"
        #RDP Group Sids for Restricted Groups
        $addConRDP = "*S-1-5-32-555__Members = *$($getRtRGRDPSid),*$($getRGRDPSid)"

        #User Rights Assignments
        $addConURARemote = "SeRemoteInteractiveLogonRight = *$($getRtRGAdminSid),*$($getRGAdminSid),*$($getRtRGRDPSid),*$($getRGRDPSid)"

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
        #FabianNiesen supplied fix so GPO is versioned to 1 and not set to 0 (zero)
        Set-ADObject -Identity $getGPOPath -Replace @{versionNumber="1"}
    }
    
