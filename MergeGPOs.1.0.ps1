#Merge GPOs - copy this script to the root of a directory with Domain GPO's that require merging. 

#Confirm for elevated admin
if (-not([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
    {
        Write-Host "An elevated administrator account is required to run this script." -ForegroundColor Red
    }
else
{
        if($psise -ne $null)
        {
        $ISEPath = $psise.CurrentFile.FullPath
        $ISEDisp = $psise.CurrentFile.DisplayName.Replace("*","")
        $PSWork = $ISEPath.TrimEnd("$ISEDisp")
        $gciGPO = Get-ChildItem $ISEWork -Recurse -File -Force
        }
        else
        {
        $PSWork = split-path -parent $MyInvocation.MyCommand.Path
        $gciGPO = Get-ChildItem $ISEWork -Recurse -File -Force
        }

        $lgpoExe = "$PSWork" + "LGPO.exe"

        foreach ($file in $gciGPO)
        {
        $fileExt = $file.Extension
        $fullname = $file.FullName

        if ($fileExt -eq ".csv")
        {
            <#
            This is a little sub-optimal - The commands that should allow overlaying audit.csv's dont work so its a last apply wins. 
            Use PolicyAnalyzer.exe to compare GPO's and manually create a RSoP for Audit settings.
            
            & $lgpoExe /a $fullname
            & auditpol.exe /restore /file:$fullname
            
            #>
            New-Item -path "C:\Windows\System32\GroupPolicy\Machine\Microsoft\Windows NT\" -Name Audit -ItemType Directory -Force
            Copy -Path $fullname -Destination "C:\Windows\System32\GroupPolicy\Machine\Microsoft\Windows NT\Audit\" -Force
        }

        if ($fileExt -eq ".pol"){& $lgpoExe /m $fullname}

        if ($fileExt -eq ".inf"){& $lgpoExe /s $fullname}
 
        }

        $bakupPath = "$PSWork" + "GPOBackup"
        New-Item -Path $PSWork -Name GPOBackup -ItemType Directory -Force

        & $lgpoExe /b $bakupPath /n GPOBackup
}
