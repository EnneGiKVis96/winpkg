
<#PSScriptInfo

.VERSION 1.4

.GUID 30675ad6-2459-427d-ac3a-3304cf103fe9

.AUTHOR ni.guerra@proton.me

.COMPANYNAME

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI https://github.com/EnneGiKVis96/casun6

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 Improving winget experience for all Windows users from 2023 

#> 
param(
    [CmdletBinding(DefaultParameterSetName='00')]     
    [Parameter(ParameterSetName='00')]
    [switch]$Update,
    [switch]$WindowsUpdate,
    [switch]$Optional,
    [Parameter(ParameterSetName='01')]
    [string]$Install,
    [string]$Version,
    [Parameter(ParameterSetName='03')]
    [string]$Find,
    [Parameter(ParameterSetName='04')]
    [string]$Exclude,
    [Parameter(ParameterSetName='05')]
    [switch]$List,
    [Parameter(ParameterSetName='06')]
    [string]$Remove,
    [Parameter(ParameterSetName='07')]
    [switch]$Help,
    [Parameter(ParameterSetName='08')]
    [string]$Process,
    [Parameter(ParameterSetName='09')]
    [switch]$AllUpdates,
    [switch]$NonMandatory
)

#Requires -Module PSWindowsUpdate
#Requires -Module Microsoft.WinGet.Client

function Update-Packages {

    $updatepackages = Get-WinGetPackage | Where-Object { ($_.IsUpdateAvailable -eq $true) -and ($_.Source -eq "winget") } | `
    Select-Object Id, Name, InstalledVersion, @{Name='LastVersion'; Expression={$_.AvailableVersions[0]}}

    if ($updatepackages.count -ne 0) {
        Write-Host "-> Updates available found: $($updatepackages.count)"

        # Check if any of the packages are excluded
        $excludedPackages = Get-Content -Path "$ExcludePath\casun6_excluded_packages.txt" -Raw

        $packagesToInstall = @()

        foreach ($package in $updatepackages) {
            if (-not [string]::IsNullOrEmpty($excludedPackages) -and $excludedPackages -notlike "*$($package.Id)*") {
                $packagesToInstall += $package
            }
        }

        if ($excludedPackages.Count -gt 0) {
            $commaexclPkg = $excludedPackages -replace "`n",", " -replace "`r",""
            
            Write-Host "-> Excluded package from update: $commaexclPkg. Ignoring ..." -ForegroundColor Yellow

        }

        if ($packagesToInstall.Count -gt 0) {
            
            $packagesToInstall | Out-Host
            
            $response = Read-Host "-> Do you want to proceed with installing $($packagesToInstall.Count) updates? (y/n)"

            if ($response -eq "y") {
                $packagesToInstall | ForEach-Object {
                    $id = $_.Id
                    $_ | Update-WinGetPackage -Mode Silent | Select-Object @{Name='Id'; Expression={$id}}, Status, RebootRequired
                }
            } else {
                Exit
            }
        } else {
            
            Write-Host "-> No updates for packages are available now`n" -ForegroundColor Yellow
        }
    } else {
        Write-Host "-> No updates for packages are available now`n" -ForegroundColor Yellow
    }
}

function Test-Administrator{  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}


function Get-WindowsKB{

    Write-Host "-> Searching Windows Updates..."

    if (($Optional.IsPresent) -or ($NonMandatory.IsPresent)){
        $checkUpdate = Get-WindowsUpdate -criteria "isinstalled=0 and deploymentaction=*"
        Return $checkUpdate
    }
    Else{
        $checkUpdate = Get-WindowsUpdate
        Return $checkUpdate

    }

}

function Update-Windows{

    $checkRights = Test-Administrator
    if ($checkRights -eq $True){
        $checkUpdate = Get-WindowsKB

        If ($null -ne $checkUpdate){
            $response = Read-Host "-> Do you want to proceed with installing $($checkUpdate.Count) Windows Updates? (y/n)"

            if ($response -eq "y") {
                
                Write-Host "-> Installing Windows Updates..." -ForegroundColor Cyan
                try{
                    if (($Optional.IsPresent) -or ($NonMandatory.IsPresent)){Install-WindowsUpdate -criteria "isinstalled=0 and deploymentaction=*"}Else{Install-WindowsUpdate}
                    Write-Host "-> Windows Updates installed successfully" -ForegroundColor Green
                }
                catch{
                    Write-Host "-> Error during installing updates" -ForegroundColor Red
                }

            } else {
                Exit
            }
            
        }
        Else{
            Write-Host "-> No Windows Updates available at the moment" -ForegroundColor Yellow
        }
    }
    Else{
        Write-Host "-> Please run this script as administrator to check for Windows Updates" -ForegroundColor Red
    }
} 

function Skip-Packages{

    $exlpackage = Get-WinGetPackage | Where-Object Id -eq $Exclude
    If ($null -ne $exlpackage){
        $exlpackage | Select-Object Name, Id, InstalledVersion | Out-Host
        $Exclude | Out-File -Append -FilePath "$ExcludePath\casun6_excluded_packages.txt"
        
        Write-Host "-> Package $Exclude is excluded from future updates`n" -ForegroundColor Green
    }
    Else{
        
        Write-Host "-> Can't find $Exclude in your system. It is not installed as a package`n" -ForegroundColor Red
    }

}

function Remove-ExcludedPackage {

    $excludedPackages = Get-Content -Path $filePath

    if ($excludedPackages -contains $Process) {
        $excludedPackages = $excludedPackages | Where-Object { $_ -ne $Process }
        $excludedPackages | Set-Content -Path $filePath -Force

        
        Write-Host "-> Package $Process has been removed from the exclusion list`n" -ForegroundColor Green
    } else {
        
        Write-Host "-> Package $Process is not in the exclusion list`n" -ForegroundColor Red
    }
}

function Install-Packages{
    $foundpackage = Find-WinGetPackage -Id $Install | Where-Object Id -eq $Install
    
    If ($foundpackage.count -ne 0){
        
        $installedpackage = Get-WinGetPackage | Where-Object Id -eq $Install
        If ($installedpackage.count -eq 0){
            $foundpackage | Select-Object Name, Id, Version | Out-Host
            Install-WinGetPackage -Id $Install -Mode Silent | Select-Object @{Name='Id'; Expression={$foundpackage.Id}}, Status, RebootRequired
        }
        Else{

            
            Write-Host "-> Package $Install is already installed in the system`n" -ForegroundColor Yellow
        
        }
    }
    Else{
        
        Write-Host "-> No packages with name $Install was found in winget`n" -ForegroundColor Red
    }

}


function Install-PackagesVersioning{
    $foundpackage = Find-WinGetPackage -Id $Install | Where-Object {($_.Id -eq $Install) -and ($_.AvailableVersions -contains $Version)}
    If ($foundpackage.count -ne 0){
        
        $installedpackage = Get-WinGetPackage | Where-Object Id -eq $Install
        If ($installedpackage.count -eq 0){
            $foundpackage | Select-Object Name, Id, @{Name='VersionRequested'; Expression={$Version}} | Out-Host
            $foundpackage | Install-WinGetPackage -Version $Version -Mode Silent | Select-Object @{Name='Id'; Expression={$foundpackage.Id}}, Status, RebootRequired
        }
        Else{
            Write-Host "-> Package $Install is already installed in the system`n" -ForegroundColor Yellow
        }
    }
    Else{
        Write-Host "-> No packages with name $Install was found in winget or the version is invalid`n" -ForegroundColor Red
    }

}


function Find-Packages{

    $foundpackages = Find-WinGetPackage $Find | Where-Object Source -eq "winget" | Select-Object Name, Id, Version, AvailableVersions
    If ($foundpackages.count -ne 0){$foundpackages}
    Else{
        Write-Host "-> No packages with name $Find was found in winget`n" -ForegroundColor Red
    }
}


function Remove-Packages{

    $installedpackage = Get-WinGetPackage | Where-Object Id -eq $Remove
    If ($installedpackage.count -ne 0){

        $installedpackage | Select-Object Name, Id, InstalledVersion | Out-Host
        
        $response =  Write-Host "-> You are uninstalling $Remove from your system."
        
        $response =  Read-Host "-> Do you want to proceed? (y/n)"
        If ($response -eq "y"){
            Uninstall-WinGetPackage -Id $Remove | Select-Object @{Name='Id'; Expression={$installedpackage.Id}}, Status, RebootRequired
        }
        Else{
            Exit
        }

    }
    Else{
        
        Write-Host "-> No packages with name $Remove was found in your system`n" -ForegroundColor Red
    }

}

$ExcludePath = $PSScriptRoot

Write-Host "`nCasun6 Winget Helper [1.4]"
Write-Host "Winget and System Updates All In One ~ Since 2023"

#Check if excluded txt is existing. Otherwise, it will create it
$filePath = "$ExcludePath\casun6_excluded_packages.txt"
if (-not (Test-Path -Path $filePath)) {
    New-Item -ItemType File -Path $filePath -Force | Out-Null
}


If ($Update.IsPresent){

    Update-Packages
    If ($WindowsUpdate.IsPresent){
        Update-Windows
    }

}ElseIf($AllUpdates.IsPresent){

    Update-Packages
    Update-Windows

}Elseif ($Install){

    If ($Version) {
        Install-PackagesVersioning
    }Else{
        Install-Packages
    }
    
}Elseif ($Find){

    Find-Packages

}ElseIf ($Exclude){

    Skip-Packages

}ElseIf ($List.IsPresent){

    Get-WinGetPackage | Where-Object Source -eq "winget" |`
    Select-Object Id, Name, InstalledVersion

}Elseif ($Remove){

    Remove-Packages

}
Elseif ($Process){

    Remove-ExcludedPackage

}
ElseIf($Help.IsPresent){

    Write-Host "`nusage: casun6 [-U update_packages][-W windows_updates][-O optional_windows_updates]"
    Write-Host "                [-A all_updates][-N nonmandatory_windows_updates]"
    Write-Host "                [-I install_packages][-V version_requested]"
    Write-Host "                [-F find_packages ]"
    Write-Host "                [-L list_installed_packages ]"
    Write-Host "                [-R remove_packages ]"
    Write-Host "                [-E exclude_packages ]"
    Write-Host "                [-P process_excludedpackages ]`n"
}

