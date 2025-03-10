
<#PSScriptInfo

.VERSION 1.5

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
    [string]$Process,
    [Parameter(ParameterSetName='09')]
    [switch]$XclusionList
)

#Requires -Module Microsoft.WinGet.Client

function Get-WinPKGUpdates {

    $scriptName = "winpkg"

    Write-Host "`n:: Checking for WinPKG updates" -ForegroundColor Cyan
    $installedVersion = $appversion

    $galleryScript = Find-Script -Name $scriptName
    $galleryVersion = $galleryScript.Version

    if ($galleryVersion -gt $installedVersion) {
        Write-Host ":: New version of WinPKG is available: $galleryVersion. Please update with Update-Script -Name winpkg" -ForegroundColor Cyan
    }
    else{
        Write-Host ":: Already running the latest version" -ForegroundColor Cyan
    }
}

function Update-Packages {

    Write-Host "`n:: Checking packages updates" -ForegroundColor Yellow
    $updatepackages = Get-WinGetPackage -Source "winget" | Where-Object IsUpdateAvailable -eq $true | `
    Select-Object Id, Name, InstalledVersion, @{Name='LastVersion'; Expression={$_.AvailableVersions[0]}}

    if ($updatepackages.count -ne 0) {
        Write-Host ":: Updates available found: $($updatepackages.count)"

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
            Write-Host ":: Excluded package from update: $excludedPackageIds. Ignoring ..." -ForegroundColor Yellow
        }

        $index = 1
        if ($packagesToInstall.Count -gt 0) {
            write-host ""
            ForEach ($updatepkg in $packagesToInstall){

                # Formattazione con larghezza fissa per allineare l'output
                $formattedInd = "{0,-5}" -f $index
                $formattedId = "{0,-40}" -f $updatepkg.Id
                $formattedVersion = "{0,-20}" -f $updatepkg.InstalledVersion
                $formattedNewVersion = "{0,-20}" -f $updatepkg.LastVersion

                # Stampa il testo con colori e formattazione
                Write-Host -NoNewLine "$formattedInd" -ForegroundColor Magenta
                Write-Host -NoNewLine "$formattedId"
                Write-Host -NoNewLine "$formattedVersion" -ForegroundColor Red
                Write-Host "$formattedNewVersion" -ForegroundColor Green

                $index ++
            }
            
            $response = Read-Host "`n:: Do you want to proceed with installing $($packagesToInstall.Count) updates? (y/n)"

            if ($response -ieq "y") {
                ForEach ($pkgup in $packagesToInstall) {
                    try{
                        $resultupdate = $pkgup| Update-WinGetPackage -Mode Silent
                        if ($resultupdate.Status -ieq "OK"){
                            Write-Host ":: The package $($pkgup.Id) is now updated to version $($pkgup.LastVersion)" -ForegroundColor Green
                        }
                        Else{
                            Write-Host ":: Something went wrong during the update for $($pkgup.Id). Please try again (Error: $($resultupdate.Status))" -ForegroundColor Red
                        }
                    }
                    catch{
                        Write-Host ":: Something went wrong : $_" -ForegroundColor Red
                    }
                }
            } else {
                Exit
            }
        } else {
            
            Write-Host ":: No updates for packages are available now`n" -ForegroundColor Yellow
        }
    } else {
        Write-Host ":: No updates for packages are available now`n" -ForegroundColor Yellow
    }
}

function Get-ExcludedPackages {

    if ($XclusionList.IsPresent){
        Write-Host "`n:: Checking exclusion list" -ForegroundColor Yellow
        if (Test-Path $jsonFilePath) {
            $ind = 1
            $jsonContent = Get-Content -Raw -Path $jsonFilePath | ConvertFrom-Json
            If ($null -ne $jsonContent -and $jsonContent.ExcludedPackages.Count -gt 0){
                Write-Host ""
                ForEach ($pkg in $jsonContent.ExcludedPackages){

                    # Formattazione con larghezza fissa per allineare l'output
                    $formattedInd = "{0,-5}" -f $ind
                    $formattedId = "{0,-40}" -f $pkg
        
                    # Stampa il testo con colori e formattazione
                    
                    Write-Host -NoNewLine "$formattedInd" -ForegroundColor Magenta
                    Write-Host "$formattedId"
                    $ind ++
                }
                Write-Host ""
                Write-Host ":: Search completed`n" -ForegroundColor Green
            }
                
            Else{
                Write-Host ":: No packages are excluded for update right now`n" -ForegroundColor Yellow
            }
            
        } else {

            $initialJson = @{
                ExcludedPackages = @()
            } | ConvertTo-Json

            $initialJson | Set-Content -Path $jsonFilePath

            return @()
        }

    }
    Else{
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

        Write-Host "`n:: Package $Exclude is excluded from future updates`n" -ForegroundColor Green

    } else {
        Write-Host "`n:: Package $Exclude is already excluded from future update`n" -ForegroundColor Red
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

        Write-Host "`n:: Package $Process has been removed from the exclusion list`n" -ForegroundColor Green
    } else {
        Write-Host "`n:: Package $Process is not in the exclusion list`n" -ForegroundColor Red
    }

}


function Install-Packages{

    $installedpackage = Get-WinGetPackage | Where-Object Id -eq $Install
    If ($installedpackage.count -eq 0){

        Write-Host "`n:: Starting installation of $Install"
        try{
            $resultinstall = Install-WinGetPackage -Id $Install -Mode Silent
            if ($resultinstall.Status -ieq "OK"){
                Write-Host ":: The package $Install is now installed in your system`n" -ForegroundColor Green
            }
            Else{
                Write-Host ":: Something went wrong during installation of $Install. Please try again (Error: $($resultinstall.Status))`n" -ForegroundColor Red
            }
        }
        catch{
            Write-Host ":: Something went wrong : $_" -ForegroundColor Red
        }
        
    }
    Else{
        Write-Host ":: Package $Install is already installed in the system`n" -ForegroundColor Yellow
        
    }

}


function Install-PackagesVersioning{
    $installedpackage = Get-WinGetPackage | Where-Object Id -eq $Install
    If ($installedpackage.count -eq 0){

        Write-Host "`n:: Starting installation of $Install on targeted version $Version"
        try{
            $resultinstall = Install-WinGetPackage -Id $Install -Version $Version -Mode Silent
            if ($resultinstall.Status -ieq "OK"){
                Write-Host ":: The package $Install is now installed in your system on targeted version $Version`n" -ForegroundColor Green
            }
            Else{
                Write-Host ":: Something went wrong during installation of $Install. Please try again (Error: $($resultinstall.Status))`n" -ForegroundColor Red
            }
        }
        catch{
            Write-Host ":: Something went wrong : $_" -ForegroundColor Red
        }
        
    }
    Else{
        Write-Host ":: Package $Install is already installed in the system`n" -ForegroundColor Yellow
        
    }

}


function Find-Packages{

    Write-Host "`n:: Searching package required" -ForegroundColor Yellow
    $foundpackages = Find-WinGetPackage $Find -Source winget | Select-Object Name, Id, Version, AvailableVersions
    $ind = 1
    If ($foundpackages.count -ne 0){
        Write-Host ""
        ForEach ($foundpkg in $foundpackages){

            # Formattazione con larghezza fissa per allineare l'output
            $formattedInd = "{0,-5}" -f $ind
            $formattedId = "{0,-40}" -f $foundpkg.Id
            $formattedVersion = "{0,-20}" -f $foundpkg.Version

            # Stampa il testo con colori e formattazione
            
            Write-Host -NoNewLine "$formattedInd" -ForegroundColor Magenta
            Write-Host -NoNewLine "$formattedId"
            Write-Host -NoNewLine "$formattedVersion" -ForegroundColor Green
            Write-Host "[$($foundpkg.AvailableVersions)]" -ForegroundColor Yellow
            $ind ++
        }
        Write-Host ""
        Write-Host ":: Search completed`n" -ForegroundColor Green
    }
    Else{
        Write-Host ":: No packages with name $Find was found in winget`n" -ForegroundColor Red
    }
}


function Remove-Packages{

    Write-Host "`n:: Searching package to remove" -ForegroundColor Yellow
    $installedpackage = Get-WinGetPackage | Where-Object Id -eq $Remove
    If ($installedpackage.count -ne 0){

        $response =  Write-Host ":: You are uninstalling $Remove from your system."
        $response =  Read-Host ":: Do you want to proceed? (y/n)"

        If ($response -ieq "y"){
            $resultuninstall = Uninstall-WinGetPackage -Id $Remove -Mode Silent
            if ($resultuninstall.Status -ieq "OK"){
                Write-Host ":: The package $Remove is now uninstalled from your system`n" -ForegroundColor Green
            }
            Else{
                Write-Host ":: Something went wrong with uninstalling $Remove. Please try again`n" -ForegroundColor Red
            }
        }
        Else{
            Exit
        }

    }
    Else{
        
        Write-Host ":: No packages with name $Remove was found in your system`n" -ForegroundColor Red
    }

}


function Get-ListPackages {

    Write-Host "`n:: Listing all packages installed`n" -ForegroundColor Yellow
    $ind = 1
    $list = Get-WinGetPackage -Source "winget" | Select-Object Id, InstalledVersion

    ForEach ($li in $list) {
        # Formattazione con larghezza fissa per allineare l'output
        $formattedInd = "{0,-5}" -f $ind
        $formattedId = "{0,-40}" -f $li.Id
        $formattedVersion = "{0,-20}" -f $li.InstalledVersion

        # Stampa il testo con colori e formattazione
        Write-Host -NoNewLine "$formattedInd" -ForegroundColor Magenta
        Write-Host -NoNewLine "$formattedId"
        Write-Host "$formattedVersion" -ForegroundColor Green
        $ind ++
    }
    
    Write-Host "`n:: Listing completed`n" -ForegroundColor Green
}

function Show-Help{

    $output = @()
    $output += "`nusage: winpkg [-U update_packages]"
    $output += "              [-I install_packages][-V version_requested]"
    $output += "              [-F find_packages]"
    $output += "              [-L list_installed_packages]"
    $output += "              [-R remove_packages]"
    $output += "              [-E exclude_packages]"
    $output += "              [-P process_excludedpackages]"
    $output += "              [-X eXclusion_list]`n"
    $output | Out-Host

}

$appversion = "1.5"
$welcome = @()
$welcome += "`nWinPKG [$appversion]"
$welcome | Out-Host

# Esegui la verifica all'avvio dello script
Get-WinPKGUpdates

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
ElseIf($XclusionList.IsPresent){

    Get-ExcludedPackages

}





