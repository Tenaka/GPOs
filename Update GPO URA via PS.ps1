#This is a rough outline of how to update gpttmpl.inf to include addtional URA or Restricted Groups
#GPO Name
$GPOName = "GPO_$($MemSrvRoot)_RestrictedGroup"

#New GPO based on the service and linked to OU
New-GPO -Name $GPOName | New-GPLink -Target $getOUMS.DistinguishedName
$getGpoId = (Get-GPO $GPOName).id
$getGPOPath = (Get-GPO $GPOName).path
$sysvol = "$($smbSysvol)\domain\Policies\{$($getGpoId)}\Machine\Microsoft\Windows NT\SecEdit"
$gptFile = "$($sysvol)\GptTmpl.inf"


#
$add = "*S-1-5-21-4000739697-4006183653-2191022337-9999"

$select = $gtCont | Select-String -Pattern "S-1-5-32-555__Members"

$combi = "$($select),$($add)"

foreach ($lin in $gtCont)
{
    if ($lin -like "*$select*")
    {
        add-Content -Value `n$combi -Path $gptFile -NoNewline
    }
    else{
        add-Content -Value `n$lin -Path $gptFile -NoNewline
    }

}
