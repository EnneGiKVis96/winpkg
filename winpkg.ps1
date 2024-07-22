
<#PSScriptInfo

.VERSION 1.1

.GUID 30675ad6-2459-427d-ac3a-3304cf103fe9

.AUTHOR ni.guerra@proton.me

.COMPANYNAME

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI https://github.com/EnneGiKVis96/winpkg

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 Better Winget CLI with Powershell 7 Official Modules

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
    [Parameter(ParameterSetName='08')]
    [string]$Process
)

#Requires -Module Microsoft.WinGet.Client

function Update-Packages {

    $updatepackages = Get-WinGetPackage | Where-Object { ($_.IsUpdateAvailable -eq $true) -and ($_.Source -eq "winget") } | `
    Select-Object Id, Name, InstalledVersion, @{Name='LastVersion'; Expression={$_.AvailableVersions[0]}}

    if ($updatepackages.count -ne 0) {
        Write-Host "-> Updates available found: $($updatepackages.count)"

        $excludedPackages = Get-ExcludedPackages
        $packagesToInstall = @()
        $excludedToInstall = @()

        ForEach ($package in $updatepackages) {
            If ($null -eq $excludedPackages -or $excludedPackages -notcontains $package.Id) {
                $packagesToInstall += $package
            }
            Else{
                $excludedToInstall += $package
            }
        }

        if ($excludedToInstall.Count -gt 0) {
            $excludedPackageIds = ($excludedToInstall | ForEach-Object { $_.Id }) -join ', '
            Write-Host "-> Excluded package from update: $excludedPackageIds. Ignoring ..." -ForegroundColor Yellow
        }

        $index = 1
        if ($packagesToInstall.Count -gt 0) {
            write-host ""
            ForEach ($updatepkg in $packagesToInstall){

                Write-Host -NoNewline "     [$index]      " -ForegroundColor Magenta
                Write-Host -NoNewLine "[winget" -ForegroundColor Cyan
                Write-Host -NoNewLine "\$($updatepkg.Id)]     "
                Write-Host -NoNewLine "[$($updatepkg.InstalledVersion)]  " -ForegroundColor Red
                Write-Host -NoNewLine "->  "
                Write-Host  "[$($updatepkg.LastVersion)]" -ForegroundColor Green
                $index ++
            }
            
            $response = Read-Host "`n-> Do you want to proceed with installing $($packagesToInstall.Count) updates? (y/n)"

            if ($response -ieq "y") {
                write-host ""
                $packagesToInstall | ForEach-Object {
                    $id = $_.Id
                    $resultupdate = $_ | Update-WinGetPackage -Mode Silent | Select-Object @{Name='Id'; Expression={$id}}, Status, RebootRequired
                    Write-Host -NoNewLine "     [winget" -ForegroundColor Cyan
                    Write-Host -NoNewLine "\$($resultupdate.Id)]  ->  "
                    if ($resultupdate.Status -ieq "OK"){Write-Host "[$($resultupdate.Status)]  " -ForegroundColor Green}Else{Write-Host "[$($resultupdate.Status)]  " -ForegroundColor Red}
                    
                }
                write-host ""
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

function Get-ExcludedPackages {

    if (Test-Path $jsonFilePath) {

        $jsonContent = Get-Content -Raw -Path $jsonFilePath | ConvertFrom-Json
        return $jsonContent.ExcludedPackages -as [string[]]
    } else {

        $initialJson = @{
            ExcludedPackages = @()
        } | ConvertTo-Json

        $initialJson | Set-Content -Path $jsonFilePath

        return @()
    }

}

function Add-ExcludedPackage {
    param (
        [string]$packageId
    )

    [string[]]$excludedPackages = Get-ExcludedPackages

    if ($packageId -notin $excludedPackages) {
        $excludedPackages += $packageId

        $jsonContent = @{
            ExcludedPackages = $excludedPackages
        }

        $jsonContent | ConvertTo-Json | Set-Content -Path $jsonFilePath

        Write-Host "-> Package $Exclude is excluded from future updates`n" -ForegroundColor Green

    } else {
        Write-Host "-> Package $Exclude is already excluded from future update`n" -ForegroundColor Red
    }

}

function Remove-ExcludedPackage {
    param (
        [string]$packageId
    )

    $excludedPackages = Get-ExcludedPackages

    if ($packageId -in $excludedPackages) {

        $excludedPackages = $excludedPackages | Where-Object { $_ -ne $packageId }

        $jsonContent = @{
            ExcludedPackages = $excludedPackages
        }

        $jsonContent | ConvertTo-Json | Set-Content -Path $jsonFilePath

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
            write-host ""
            Write-Host -NoNewLine "     [winget" -ForegroundColor Cyan
            Write-Host -NoNewLine "\$($foundpackage.Id)]     "
            Write-Host -NoNewLine "[$($foundpackage.Name)]  "
            Write-Host -NoNewLine "->  "
            Write-Host  "[$($foundpackage.Version)]" -ForegroundColor Green
            write-host ""

            Write-Host "Starting installation of $($foundpackage.Id)"
            $resultinstall = Install-WinGetPackage -Id $Install -Mode Silent | Select-Object @{Name='Id'; Expression={$foundpackage.Id}}, Status, RebootRequired

            write-host ""
            Write-Host -NoNewLine "     [winget" -ForegroundColor Cyan
            Write-Host -NoNewLine "\$($resultinstall.Id)]  ->  "
            if ($resultinstall.Status -ieq "OK"){Write-Host "[$($resultinstall.Status)]  " -ForegroundColor Green}Else{Write-Host "[$($resultinstall.Status)]  " -ForegroundColor Red}
            write-host ""
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
            write-host ""
            Write-Host -NoNewLine "     [winget" -ForegroundColor Cyan
            Write-Host -NoNewLine "\$($foundpackage.Id)]     "
            Write-Host -NoNewLine "[$($foundpackage.Name)]  "
            Write-Host -NoNewLine "->  "
            Write-Host  "[$Version)]" -ForegroundColor Green
            write-host ""
            Write-Host "Starting installation of $($foundpackage.Id)"
            $resultinstall = Install-WinGetPackage -Id $Install -Version $Version -Mode Silent | Select-Object @{Name='Id'; Expression={$foundpackage.Id}}, Status, RebootRequired
            write-host ""
            Write-Host -NoNewLine "     [winget" -ForegroundColor Cyan
            Write-Host -NoNewLine "\$($resultinstall.Id)]  ->  "
            if ($resultinstall.Status -ieq "OK"){Write-Host "[$($resultinstall.Status)]  " -ForegroundColor Green}Else{Write-Host "[$($resultinstall.Status)]  " -ForegroundColor Red}
            write-host ""
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
    $index = 1
    If ($foundpackages.count -ne 0){
        write-host ""
        ForEach ($foundpkg in $foundpackages){

            Write-Host -NoNewline "     [$index]      " -ForegroundColor Magenta
            Write-Host -NoNewLine "[winget" -ForegroundColor Cyan
            Write-Host -NoNewLine "\$($foundpkg.Id)]     "
            Write-Host -NoNewLine "[$($foundpkg.Version)]  " -ForegroundColor Green
            Write-Host -NoNewLine "-  "
            Write-Host  "[$($foundpkg.AvailableVersions)]" -ForegroundColor Yellow
            $index ++
        }
        write-host ""
    }
    Else{
        Write-Host "-> No packages with name $Find was found in winget`n" -ForegroundColor Red
    }
}


function Remove-Packages{

    $installedpackage = Get-WinGetPackage | Where-Object Id -eq $Remove
    If ($installedpackage.count -ne 0){
        write-host ""
        Write-Host -NoNewLine "     [winget" -ForegroundColor Cyan
        Write-Host -NoNewLine "\$($installedpackage.Id)]     "
        Write-Host -NoNewLine "[$($installedpackage.Name)]  "
        Write-Host -NoNewLine "-  "
        Write-Host  "[$($installedpackage.InstalledVersion)]" -ForegroundColor Yellow
        write-host ""
        $response =  Write-Host "-> You are uninstalling $Remove from your system."
        $response =  Read-Host "-> Do you want to proceed? (y/n)"

        If ($response -ieq "y"){
            $resultuninstall = Uninstall-WinGetPackage -Id $Remove | Select-Object @{Name='Id'; Expression={$installedpackage.Id}}, Status, RebootRequired
            write-host ""
            Write-Host -NoNewLine "     [winget" -ForegroundColor Cyan
            Write-Host -NoNewLine "\$($resultuninstall.Id)]  ->  "
            if ($resultuninstall.Status -ieq "OK"){Write-Host "[$($resultuninstall.Status)]  " -ForegroundColor Green}Else{Write-Host "[$($resultuninstall.Status)]  " -ForegroundColor Red}
            write-host ""
        }
        Else{
            Exit
        }

    }
    Else{
        
        Write-Host "-> No packages with name $Remove was found in your system`n" -ForegroundColor Red
    }

}


function Get-ListPackages{
    $index = 1
    $list = Get-WinGetPackage | Where-Object Source -eq "winget" | Select-Object Id, Name, InstalledVersion

    write-host ""
    ForEach ($li in $list){

        Write-Host -NoNewline "     [$index]      " -ForegroundColor Magenta
        Write-Host -NoNewLine "[winget" -ForegroundColor Cyan
        Write-Host -NoNewLine "\$($li.Id)]  ->  "
        Write-Host "[$($li.InstalledVersion)]  " -ForegroundColor Green
        $index ++
    }
    write-host ""
}

function Show-Help{

    $output = @()
    $output += "`nusage: winpkg [-U update_packages]"
    $output += "                [-I install_packages][-V version_requested]"
    $output += "                [-F find_packages]"
    $output += "                [-L list_installed_packages]"
    $output += "                [-R remove_packages]"
    $output += "                [-E exclude_packages]"
    $output += "                [-P process_excludedpackages]`n"
    $output | Out-Host

}

$welcome = @()
$welcome += "`nWinPKG [1.1]"
$welcome | Out-Host

$jsonFilePath = Join-Path $PSScriptRoot "exclusions.json"

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

    Add-ExcludedPackage -packageId $Exclude

}ElseIf ($List.IsPresent){

    Get-ListPackages
    

}Elseif ($Remove){

    Remove-Packages

}
Elseif ($Process){

    Remove-ExcludedPackage -packageId $Process

}
ElseIf($Help.IsPresent){

    Show-Help

}

