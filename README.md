
# WinPKG

WinPKG is a Powershell Script to simplify the package manager winget and create a single unified CLI for packages.

## Installation

Install winpkg script with Powershell

```bash
  Install-Script -Name winpkg
```
It will install the script and his dependency: Microsoft.WinGet.Client

## Update

You can update winpkg in the same way using Powershell

```bash
  Update-Script -Name winpkg
```


## Features 

- Install winget packages 
- Update winget packages 
- List installed winget packages
- Find packages in the winget repo
- Exclude and include packages from updating

## Usage/Examples

Check all available commands:
```powershell
winpkg -H 
```

Install a package from winget:
```powershell
winpkg -I WinSCP.WinSCP
winpkg -I WinSCP.WinSCP -V 6.1.1 # You can specify the version if available
```

Update packages:
```powershell
winpkg -U
```

Find any package in the winget repos:
```powershell
winpkg -F WinSCP 
```

Remove a package from your system:
```powershell
winpkg -R WinSCP.WinSCP 
```

List your installed packages
```powershell
winpkg -L
```

Exclude a package / include a package previously excluded
```powershell
winpkg -E WinSCP.WinSCP # To exclude
winpkg -P WinSCP.WinSCP # To remove the exclusion
```

List your excluded packages
```powershell
winpkg -X
```