<#PSScriptInfo

.VERSION 1.6

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

# Constants
$SCRIPT_VERSION = "1.6"
$JSON_FILE_PATH = Join-Path $PSScriptRoot "exclusions.json"

# Visual Elements
$SEPARATOR = "═" * 80
$SUCCESS_ICON = "✓"
$ERROR_ICON = "✗"
$INFO_ICON = "ℹ"
$WARNING_ICON = "⚠"
$PROGRESS_ICON = "⟳"

# Title with Unicode styling
$TITLE = "╔══════════════════════════════════════════════════════════════════════════════╗`n" + 
        "║                                                                              ║`n" +
        "║  ██╗    ██╗██╗███╗   ██╗██████╗  ██╗  ██╗ ██████╗                            ║`n" +
        "║  ██║    ██║██║████╗  ██║██╔══██╗ ██║ ██╔╝██╔════╝                            ║`n" +
        "║  ██║ █╗ ██║██║██╔██╗ ██║██████╔╝ █████╔╝ ██║                                 ║`n" +
        "║  ██║███╗██║██║██║╚██╗██║██╔═══╝  ██╔═██╗ ██║   ██    [$SCRIPT_VERSION]                   ║`n" +
        "║  ╚███╔███╔╝██║██║ ╚████║██║      ██║  ██╗╚██████╗                            ║`n" +
        "║   ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚═╝      ╚═╝  ╚═╝ ╚═════╝                            ║`n" +
        "║                                                                              ║`n" +
        "╚══════════════════════════════════════════════════════════════════════════════╝"

# Utility functions
function Write-Status {
    param(
        [string]$Message,
        [string]$Color = "Blue",
        [string]$Icon = $INFO_ICON,
        [switch]$NoNewLine
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    $formattedMessage = "[$timestamp] $Icon $Message"
    if ($NoNewLine) {
        Write-Host $formattedMessage -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $formattedMessage -ForegroundColor $Color
    }
}

function Write-Header {
    param([string]$Title)
    Write-Host "`n$SEPARATOR"
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host $SEPARATOR
}

function Write-Success {
    param([string]$Message)
    Write-Status -Message $Message -Color "Green" -Icon $SUCCESS_ICON
}

function Write-Error {
    param([string]$Message)
    Write-Status -Message $Message -Color "Red" -Icon $ERROR_ICON
}

function Write-Warning {
    param([string]$Message)
    Write-Status -Message $Message -Color "Yellow" -Icon $WARNING_ICON
}

function Write-Progress {
    param(
        [string]$Message,
        [int]$Percent
    )
    $progressBar = "[" + ("█" * ($Percent / 2)) + (" " * (50 - ($Percent / 2))) + "]"
    $progressText = "[$((Get-Date).ToString('HH:mm:ss'))] $PROGRESS_ICON $Message $progressBar $Percent%"
    Write-Host "`r$progressText" -ForegroundColor Cyan -NoNewline
    if ($Percent -eq 100) {
        Write-Host ""  # Aggiungi una nuova riga solo quando raggiungiamo il 100%
    }
}

function Format-PackageOutput {
    param(
        [int]$Index,
        [string]$Id,
        [string]$Version,
        [string]$NewVersion = $null
    )
    $formattedInd = "{0,-5}" -f $Index
    $formattedId = "{0,-40}" -f $Id
    $formattedVersion = "{0,-20}" -f $Version
    
    Write-Host -NoNewLine $formattedInd -ForegroundColor Magenta
    Write-Host -NoNewLine $formattedId
    Write-Host -NoNewLine $formattedVersion -ForegroundColor Red
    
    if ($NewVersion) {
        Write-Host $NewVersion -ForegroundColor Green
    } else {
        Write-Host ""
    }
}

function Get-WinPKGUpdates {
    $jsonContent = @{
        ExcludedPackages = @()
        LastUpdateCheck = $null
    }
    
    if (Test-Path $JSON_FILE_PATH) {
        try {
            $existingContent = Get-Content -Raw -Path $JSON_FILE_PATH | ConvertFrom-Json
            if ($existingContent.ExcludedPackages) {
                $jsonContent.ExcludedPackages = $existingContent.ExcludedPackages
            }
            if ($existingContent.LastUpdateCheck) {
                $jsonContent.LastUpdateCheck = $existingContent.LastUpdateCheck
            }
        } catch {
            Write-Status "Failed to read JSON file: $_" "Red"
        }
    }

    $shouldCheck = $true
    if ($jsonContent.LastUpdateCheck) {
        try {
            $lastCheck = [DateTime]::Parse($jsonContent.LastUpdateCheck, [System.Globalization.CultureInfo]::CurrentCulture)
            $today = Get-Date
            if (($today - $lastCheck).TotalDays -lt 1) {
                $shouldCheck = $false
            }
        } catch {
            Write-Status "Failed to parse last update check time: $_" "Red"
            $shouldCheck = $true
        }
    }

    if (-not $shouldCheck) {
        return
    }

    Write-Status "Checking for WinPKG updates" "Cyan"
    try {
        $galleryScript = Find-Script -Name "winpkg" -ErrorAction Stop
        if ($galleryScript.Version -gt $SCRIPT_VERSION) {
            Write-Status "New version of WinPKG is available: $($galleryScript.Version). Please update with Update-Script -Name winpkg" "Yellow"
            exit
        } else {
            Write-Status "Already running the latest version" "Cyan"
        }
        $jsonContent.LastUpdateCheck = (Get-Date).ToString("G", [System.Globalization.CultureInfo]::CurrentCulture)
        $jsonContent | ConvertTo-Json | Set-Content -Path $JSON_FILE_PATH
    } catch {
        Write-Status "Failed to check for updates: $_" "Red"
    }
}

function Update-Packages {
    Write-Header "Checking for Updates"
    
    try {
        $updatePackages = Get-WinGetPackage -Source "winget" | 
            Where-Object IsUpdateAvailable -eq $true |
            Select-Object Id, Name, InstalledVersion, @{Name='LastVersion'; Expression={$_.AvailableVersions[0]}}

        if (-not $updatePackages) {
            Write-Warning "No updates available"
            return
        }

        Write-Success "Found $($updatePackages.count) updates available"
        
        $excludedPackages = Get-ExcludedPackages
        $packagesToInstall = $updatePackages | Where-Object { $excludedPackages -notcontains $_.Id }
        $excludedToInstall = $updatePackages | Where-Object { $excludedPackages -contains $_.Id }

        if ($excludedToInstall) {
            Write-Header "Excluded from Updates"
            $excludedPackageIds = ($excludedToInstall.Id) -join ', '
            Write-Warning "Excluded packages: $excludedPackageIds"
        }

        if ($packagesToInstall) {
            Write-Header "Available Updates"
            # Intestazione tabella
            Write-Host ("{0,-5}{1,-60}{2,-20}{3,-20}" -f "#", "Package ID", "Current Version", "New Version") -ForegroundColor Cyan
            Write-Host ("{0,-5}{1,-60}{2,-20}{3,-20}" -f ("-"*1), ("-"*10), ("-"*14), ("-"*10)) -ForegroundColor Cyan
            
            $i = 1
            foreach ($pkg in $packagesToInstall) {
                # Tronca l'ID se troppo lungo
                $displayId = if ($pkg.Id.Length -gt 57) {
                    $pkg.Id.Substring(0, 54) + "..."
                } else {
                    $pkg.Id
                }
                Write-Host -NoNewline ("{0,-5}" -f $i) -ForegroundColor Magenta
                Write-Host -NoNewline ("{0,-60}" -f $displayId)
                Write-Host -NoNewline ("{0,-20}" -f $pkg.InstalledVersion) -ForegroundColor Red
                Write-Host ("{0,-20}" -f $pkg.LastVersion) -ForegroundColor Green
                $i++
            }

            $response = Read-Host "`nDo you want to proceed with installing $($packagesToInstall.Count) updates? (y/n)"
            if ($response -ieq "y") {
                $results = @()

                foreach ($pkg in $packagesToInstall) {
                    Write-Progress -Message "Updating $($pkg.Id)" -Percent 0
                    Start-Sleep -Milliseconds 500
                    
                    try {
                        Write-Progress -Message "Updating $($pkg.Id)" -Percent 50
                        $result = $pkg | Update-WinGetPackage -Mode Silent -ProgressAction SilentlyContinue
                        
                        Write-Progress -Message "Updating $($pkg.Id)" -Percent 100
                        Start-Sleep -Milliseconds 500
                        
                        $results += [PSCustomObject]@{
                            Id = $pkg.Id
                            LastVersion = $pkg.LastVersion
                            Status = $result.Status
                            Success = ($result.Status -ieq "OK")
                        }
                    } catch {
                        $results += [PSCustomObject]@{
                            Id = $pkg.Id
                            LastVersion = $pkg.LastVersion
                            Status = $_.Exception.Message
                            Success = $false
                        }
                    }
                }

                Write-Header "Update Results"
                foreach ($result in $results) {
                    if ($result.Success) {
                        Write-Success "Updated $($result.Id) to version $($result.LastVersion)"
                    } else {
                        Write-Error "Failed to update $($result.Id). Error: $($result.Status)"
                    }
                }
            }
        }
    } catch {
        Write-Error "Failed to update packages: $_"
    }
}

function Get-ExcludedPackages {
    if ($XclusionList.IsPresent) {
        Write-Header "Excluded Packages List"
        if (Test-Path $JSON_FILE_PATH) {
            try {
                $jsonContent = Get-Content -Raw -Path $JSON_FILE_PATH | ConvertFrom-Json
                if ($jsonContent.ExcludedPackages -and $jsonContent.ExcludedPackages.Count -gt 0) {
                    # Intestazione tabella
                    Write-Host ("{0,-5}{1,-60}" -f "#", "Package ID") -ForegroundColor Cyan
                    Write-Host ("{0,-5}{1,-60}" -f ("-"*1), ("-"*10)) -ForegroundColor Cyan
                    
                    $i = 1
                    $jsonContent.ExcludedPackages | Sort-Object -Unique | ForEach-Object {
                        # Tronca l'ID se troppo lungo
                        $displayId = if ($_.Length -gt 57) {
                            $_.Substring(0, 54) + "..."
                        } else {
                            $_
                        }
                        Write-Host -NoNewline ("{0,-5}" -f $i) -ForegroundColor Magenta
                        Write-Host ("{0,-60}" -f $displayId)
                        $i++
                    }
                    Write-Success "Found $($jsonContent.ExcludedPackages.Count) excluded packages"
                } else {
                    Write-Warning "No packages are excluded for update right now"
                }
            } catch {
                Write-Error "Failed to read exclusion list: $_"
            }
        }
        return
    }

    try {
        if (Test-Path $JSON_FILE_PATH) {
            $jsonContent = Get-Content -Raw -Path $JSON_FILE_PATH | ConvertFrom-Json
            if ($jsonContent.ExcludedPackages -is [string]) {
                # Convert single string to array if needed
                return @($jsonContent.ExcludedPackages)
            }
            return $jsonContent.ExcludedPackages -as [string[]]
        } else {
            $initialJson = @{
                ExcludedPackages = @()
            } | ConvertTo-Json
            $initialJson | Set-Content -Path $JSON_FILE_PATH
            return @()
        }
    } catch {
        Write-Error "Failed to get excluded packages: $_"
        return @()
    }
}

function Add-ExcludedPackage {
    param([string]$packageId)
    
    try {
        $excludedPackages = Get-ExcludedPackages
        if ($excludedPackages -is [string]) {
            $excludedPackages = @($excludedPackages)
        }
        
        if ($packageId -notin $excludedPackages) {
            $excludedPackages = @($excludedPackages) + $packageId
            $jsonContent = @{
                ExcludedPackages = $excludedPackages
            }
            $jsonContent | ConvertTo-Json | Set-Content -Path $JSON_FILE_PATH
            Write-Success "Package $packageId is excluded from future updates"
        } else {
            Write-Warning "Package $packageId is already excluded from future update"
        }
    } catch {
        Write-Error "Failed to add excluded package: $_"
    }
}

function Remove-ExcludedPackage {
    param([string]$packageId)
    
    try {
        $excludedPackages = Get-ExcludedPackages
        if ($excludedPackages -is [string]) {
            $excludedPackages = @($excludedPackages)
        }
        
        if ($packageId -in $excludedPackages) {
            $excludedPackages = $excludedPackages | Where-Object { $_ -ne $packageId }
            $jsonContent = @{
                ExcludedPackages = $excludedPackages
            }
            $jsonContent | ConvertTo-Json | Set-Content -Path $JSON_FILE_PATH
            Write-Success "Package $packageId has been removed from the exclusion list"
        } else {
            Write-Warning "Package $packageId is not in the exclusion list"
        }
    } catch {
        Write-Error "Failed to remove excluded package: $_"
    }
}

function Install-Packages {
    param(
        [string]$PackageId,
        [string]$Version = $null
    )
    Write-Header "Package Installation"
    
    try {
        if (-not (Get-WinGetPackage | Where-Object Id -eq $PackageId)) {
            Write-Status "Starting installation of $PackageId"
            $params = @{
                Id = $PackageId
                Mode = "Silent"
            }
            if ($Version) {
                $params.Version = $Version
            }
            
            $result = Install-WinGetPackage @params
            if ($result.Status -ieq "OK") {
                Write-Status "The package $PackageId is now installed in your system" "Green"
            } else {
                Write-Status "Installation failed for $PackageId. Error: $($result.Status)" "Red"
            }
        } else {
            Write-Status "Package $PackageId is already installed in the system" "Yellow"
        }
    } catch {
        Write-Status "Installation failed: $_" "Red"
    }
}

function Find-Packages {
    param([string]$SearchTerm)
    Write-Header "Package Search Results"
    Write-Status "Searching package required" "Yellow"
    try {
        $foundPackages = Find-WinGetPackage $SearchTerm -Source winget | 
            Select-Object Name, Id, Version, AvailableVersions
        
        if ($foundPackages) {
            # Intestazione tabella
            Write-Host ("{0,-5}{1,-60}{2,-20}{3,-20}" -f "#", "Package ID", "Version", "Latest Versions") -ForegroundColor Cyan
            Write-Host ("{0,-5}{1,-60}{2,-20}{3,-20}" -f ("-"*1), ("-"*10), ("-"*7), ("-"*13)) -ForegroundColor Cyan
            
            $i = 1
            foreach ($pkg in $foundPackages) {
                # Tronca l'ID se troppo lungo
                $displayId = if ($pkg.Id.Length -gt 57) {
                    $pkg.Id.Substring(0, 54) + "..."
                } else {
                    $pkg.Id
                }
                # Prendi solo le ultime 7 versioni
                $latestVersions = if ($pkg.AvailableVersions.Count -gt 7) {
                    ($pkg.AvailableVersions | Select-Object -First 7) -join ", "
                } else {
                    $pkg.AvailableVersions -join ", "
                }
                
                Write-Host -NoNewline ("{0,-5}" -f $i) -ForegroundColor Magenta
                Write-Host -NoNewline ("{0,-60}" -f $displayId)
                Write-Host -NoNewline ("{0,-20}" -f $pkg.Version) -ForegroundColor Red
                Write-Host ("{0,-20}" -f $latestVersions) -ForegroundColor Yellow
                $i++
            }
            Write-Status "Search completed" "Green"
        } else {
            Write-Status "No packages with name $SearchTerm was found in winget" "Red"
        }
    } catch {
        Write-Status "Search failed: $_" "Red"
    }
}

function Remove-Packages {
    param([string]$PackageId)
    Write-Header "Package Removal"
    Write-Status "Searching package to remove" "Yellow"
    try {
        $installedPackage = Get-WinGetPackage | Where-Object Id -eq $PackageId
        if ($installedPackage) {
            $response = Read-Host ":: You are uninstalling $PackageId from your system. Do you want to proceed? (y/n)"
            if ($response -ieq "y") {
                $result = Uninstall-WinGetPackage -Id $PackageId -Mode Silent
                if ($result.Status -ieq "OK") {
                    Write-Status "The package $PackageId is now uninstalled from your system" "Green"
                } else {
                    Write-Status "Uninstallation failed for $PackageId. Error: $($result.Status)" "Red"
                }
            }
        } else {
            Write-Status "No packages with name $PackageId was found in your system" "Red"
        }
    } catch {
        Write-Status "Uninstallation failed: $_" "Red"
    }
}

function Get-ListPackages {
    Write-Header "Installed Packages"
    Write-Status "Listing all packages installed" "Yellow"
    try {
        $packages = Get-WinGetPackage -Source "winget" | Select-Object Id, InstalledVersion
        if ($packages) {
            # Intestazione tabella con larghezza aumentata per PackageID
            Write-Host ("{0,-5}{1,-60}{2,-20}" -f "#", "Package ID", "Version") -ForegroundColor Cyan
            Write-Host ("{0,-5}{1,-60}{2,-20}" -f ("-"*1), ("-"*10), ("-"*7)) -ForegroundColor Cyan
            $i = 1
            foreach ($pkg in $packages) {
                # Tronca l'ID se troppo lungo
                $displayId = if ($pkg.Id.Length -gt 57) {
                    $pkg.Id.Substring(0, 54) + "..."
                } else {
                    $pkg.Id
                }
                Write-Host -NoNewline ("{0,-5}" -f $i) -ForegroundColor Magenta
                Write-Host -NoNewline ("{0,-60}" -f $displayId)
                Write-Host ("{0,-20}" -f $pkg.InstalledVersion) -ForegroundColor Red
                $i++
            }
        } else {
            Write-Warning "No packages found."
        }
        Write-Status "Listing completed" "Green"
    } catch {
        Write-Status "Failed to list packages: $_" "Red"
    }
}

function Show-Help {
    Write-Header "Help"
    @"
Usage: winpkg [options]

Options:
  -U, --update              Update all available packages
  -I, --install <package>   Install a specific package
  -V, --version <version>   Specify version for installation
  -F, --find <package>      Search for packages
  -L, --list               List all installed packages
  -R, --remove <package>    Remove a package
  -E, --exclude <package>   Exclude package from updates
  -P, --process <package>   Process excluded package
  -X, --exclusion-list     Show excluded packages list
  -H, --help               Show this help message

Examples:
  winpkg -U                 # Update all packages
  winpkg -I "Microsoft.VisualStudioCode"  # Install VS Code
  winpkg -F "python"        # Search for Python packages
  winpkg -L                 # List installed packages
"@ | Out-Host
    Write-Host $SEPARATOR
}

# Main execution
Write-Host $TITLE -ForegroundColor Cyan
Write-Host $SEPARATOR
Get-WinPKGUpdates

# Process command line arguments
if ($Update.IsPresent) {
    Update-Packages
}
elseif ($Install) {
    Install-Packages -PackageId $Install -Version $Version
}
elseif ($Find) {
    Find-Packages -SearchTerm $Find
}
elseif ($Exclude) {
    Add-ExcludedPackage -packageId $Exclude
}
elseif ($List.IsPresent) {
    Get-ListPackages
}
elseif ($Remove) {
    Remove-Packages -PackageId $Remove
}
elseif ($Process) {
    Remove-ExcludedPackage -packageId $Process
}
elseif ($Help.IsPresent) {
    Show-Help
}
elseif ($XclusionList.IsPresent) {
    Get-ExcludedPackages
}
else {
    Show-Help
}





