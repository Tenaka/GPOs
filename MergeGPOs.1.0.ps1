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

        if ($fileExt -eq ".csv"){& $lgpoExe /a $fullname}

        if ($fileExt -eq ".pol"){& $lgpoExe /m $fullname}

        if ($fileExt -eq ".inf"){& $lgpoExe /s $fullname}
 
        }

        $bakupPath = "$PSWork" + "GPOBackup"
        New-Item -Path $PSWork -Name GPOBackup -ItemType Directory -Force

        & $lgpoExe /b $bakupPath /n GPOBackup
}