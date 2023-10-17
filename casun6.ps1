
<#PSScriptInfo

.VERSION 1.2

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
    [Parameter(ParameterSetName='04')]
    [string]$Process
)

#Requires -Module Microsoft.WinGet.Client

function Update-Packages {

    $updatepackages = Get-WinGetPackage | Where-Object { ($_.IsUpdateAvailable -eq $true) -and ($_.Source -eq "winget") } | `
    Select-Object Id, Name, InstalledVersion, @{Name='LastVersion'; Expression={$_.AvailableVersions[0]}}

    $date = Get-Date -UFormat "%m/%d/%Y %R"
    Write-Host "[$date] " -NoNewLine -ForegroundColor White
    if ($updatepackages.count -ne 0) {
        Write-Host "Updates available found: $($updatepackages.count)"

        # Check if any of the packages are excluded
        $excludedPackages = Get-Content -Path "$ExcludePath\casun6_excluded_packages.txt" -Raw

        $packagesToInstall = @()
        foreach ($package in $updatepackages) {
            if (-not [string]::IsNullOrEmpty($excludedPackages) -and $excludedPackages -notlike "*$($package.Id)*") {
                $packagesToInstall += $package
            } else {
                $date = Get-Date -UFormat "%m/%d/%Y %R"
                Write-Host "`n[$date] " -NoNewLine -ForegroundColor White
                Write-Host "Excluded package from update: $($package.Id). Ignoring ..." -ForegroundColor Yellow
            }
        }

        if ($packagesToInstall.Count -gt 0) {
            
            $packagesToInstall | Out-Host
            $date = Get-Date -UFormat "%m/%d/%Y %R"
            Write-Host "`n[$date] " -NoNewLine -ForegroundColor White
            $response = Read-Host "Do you want to proceed with installing $($packagesToInstall.Count) updates? (y/n)"

            if ($response -eq "y") {
                $packagesToInstall | ForEach-Object {
                    $id = $_.Id
                    $_ | Update-WinGetPackage -Mode Silent | Select-Object @{Name='Id'; Expression={$id}}, Status, RebootRequired
                }
            } else {
                Exit
            }
        } else {
            $date = Get-Date -UFormat "%m/%d/%Y %R"
            Write-Host "`n[$date] " -NoNewLine -ForegroundColor White
            Write-Host "No updates for packages are available now`n" -ForegroundColor Yellow
        }
    } else {
        Write-Host "No updates for packages are available now`n" -ForegroundColor Yellow
    }
}


function Skip-Packages{

    $exlpackage = Get-WinGetPackage | Where-Object Id -eq $Exclude
    If ($null -ne $exlpackage){
        $exlpackage | Select-Object Name, Id, InstalledVersion | Out-Host
        $Exclude | Out-File -Append -FilePath "$ExcludePath\casun6_excluded_packages.txt"
        $date = Get-Date -UFormat "%m/%d/%Y %R"
        Write-Host "`n[$date] " -NoNewLine -ForegroundColor White
        Write-Host "Package $Exclude is excluded from future updates`n" -ForegroundColor Green
    }
    Else{
        $date = Get-Date -UFormat "%m/%d/%Y %R"
        Write-Host "`n[$date] " -NoNewLine -ForegroundColor White
        Write-Host "Can't find $Exclude in your system. It is not installed as a package`n" -ForegroundColor Red
    }

}

function Remove-ExcludedPackage {

    $excludedPackages = Get-Content -Path $filePath

    if ($excludedPackages -contains $Process) {
        $excludedPackages = $excludedPackages | Where-Object { $_ -ne $Process }
        $excludedPackages | Set-Content -Path $filePath -Force

        $date = Get-Date -UFormat "%m/%d/%Y %R"
        Write-Host "`n[$date] " -NoNewLine -ForegroundColor White
        Write-Host "Package $Process has been removed from the exclusion list`n" -ForegroundColor Green
    } else {
        $date = Get-Date -UFormat "%m/%d/%Y %R"
        Write-Host "`n[$date] " -NoNewLine -ForegroundColor White
        Write-Host "Package $Process is not in the exclusion list`n" -ForegroundColor Red
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

            $date = Get-Date -UFormat "%m/%d/%Y %R"
            Write-Host "`n[$date] " -NoNewLine -ForegroundColor White
            Write-Host "Package $Install is already installed in the system`n" -ForegroundColor Yellow
        
        }
    }
    Else{
        $date = Get-Date -UFormat "%m/%d/%Y %R"
        Write-Host "`n[$date] " -NoNewLine -ForegroundColor White
        Write-Host "No packages with name $Install was found in winget`n" -ForegroundColor Red
    }

}


function Install-PackagesVersioning{
    $foundpackage = Find-WinGetPackage -Id $Install | Where-Object {($_.Id -eq $Install) -and ($_.AvailableVersions -contains $Version)}
    If ($foundpackage.count -ne 0){
        
        $installedpackage = Get-WinGetPackage | Where-Object Id -eq $Install
        If ($installedpackage.count -eq 0){
            $foundpackage | Select-Object Name, Id, @{Name='VersionRequested'; Expression={$Version}} | Out-Host
            $foundpackage | Install-WinGetPackage -Version $Version -Mode Silent | Select-Object @{Name='Id'; Expression={$foundpackage.Id}}, Status, RebootRequired
            #Install-WinGetPackage -Id $Install -Version $Version -Mode Silent | Select-Object @{Name='Id'; Expression={$foundpackage.Id}}, Status, RebootRequired
        }
        Else{

            $date = Get-Date -UFormat "%m/%d/%Y %R"
            Write-Host "`n[$date] " -NoNewLine -ForegroundColor White
            Write-Host "Package $Install is already installed in the system`n" -ForegroundColor Yellow
        
        }
    }
    Else{
        $date = Get-Date -UFormat "%m/%d/%Y %R"
        Write-Host "`n[$date] " -NoNewLine -ForegroundColor White
        Write-Host "No packages with name $Install was found in winget or the version is invalid`n" -ForegroundColor Red
    }

}


function Find-Packages{

    $foundpackages = Find-WinGetPackage $Find | Where-Object Source -eq "winget" | Select-Object Name, Id, Version, AvailableVersions
    If ($foundpackages.count -ne 0){$foundpackages}
    Else{
        $date = Get-Date -UFormat "%m/%d/%Y %R"
        Write-Host "`n[$date] " -NoNewLine -ForegroundColor White
        Write-Host "No packages with name $Find was found in winget`n" -ForegroundColor Red
    }
}


function Remove-Packages{

    $installedpackage = Get-WinGetPackage | Where-Object Id -eq $Remove
    If ($installedpackage.count -ne 0){

        $installedpackage | Select-Object Name, Id, InstalledVersion | Out-Host
        $date = Get-Date -UFormat "%m/%d/%Y %R"
        Write-Host "[$date] " -NoNewLine -ForegroundColor White
        $response =  Write-Host "You are uninstalling $Remove from your system."
        $date = Get-Date -UFormat "%m/%d/%Y %R"
        Write-Host "[$date] " -NoNewLine -ForegroundColor White
        $response =  Read-Host "Do you want to proceed? (y/n)"
        If ($response -eq "y"){
            Uninstall-WinGetPackage -Id $Remove | Select-Object @{Name='Id'; Expression={$installedpackage.Id}}, Status, RebootRequired
        }
        Else{
            Exit
        }

    }
    Else{
        $date = Get-Date -UFormat "%m/%d/%Y %R"
        Write-Host "`n[$date] " -NoNewLine -ForegroundColor White
        Write-Host "No packages with name $Remove was found in your system`n" -ForegroundColor Red
    }

}

$ExcludePath = $PSScriptRoot

Write-Host "`nCasun6 Winget Helper [1.2]"
Write-Host "Improving winget experience for all Windows users from 2023"

#Check if excluded txt is existing. Otherwise, it will create it
$filePath = "$ExcludePath\casun6_excluded_packages.txt"
if (-not (Test-Path -Path $filePath)) {
    New-Item -ItemType File -Path $filePath -Force | Out-Null
}


If ($Update.IsPresent){

    Update-Packages

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

    Write-Host "`nusage: casun6 [-U update_packages]"
    Write-Host "                [-I install_packages][-V version_requested]"
    Write-Host "                [-F find_packages ]"
    Write-Host "                [-L list_installed_packages ]"
    Write-Host "                [-R remove_packages ]"
    Write-Host "                [-E exclude_packages ]"
    Write-Host "                [-P process_excludedpackages ]`n"
}

