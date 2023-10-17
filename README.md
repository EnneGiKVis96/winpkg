
# Casun6 Winget Helper

Improving winget experience for all Windows users from 2023


## Badges

[![GPLv3 License](https://img.shields.io/badge/License-GPL%20v3-yellow.svg)](https://opensource.org/licenses/)
[![powershellgallery](https://www.powershellgallery.com/Content/Images/Branding/psgallerylogo.svg)](https://www.powershellgallery.com/packages/casun6)



## Installation

Install casun6 script with Powershell

```bash
  Install-Script -Name casun6
```
It will install the script and his dependency: Microsoft.WinGet.Client

## Update

You can update casun6 in the same way using Powershell

```bash
  Update-Script -Name casun6
```


## Features 

- Install winget packages 
- Update winget packages 
- List intalled winget packages
- Find packages in the winget repos
- [NEW] Exclude and include packages from updating



## Usage/Examples

Check all available commands:
```powershell
casun6 -H 
```

Install a package from winget:
```powershell
casun6 -I WinSCP.WinSCP
casun6 -I WinSCP.WinSCP -V 6.1.1 # You can specify the version if available
```

Find any package in the winget repos
```powershell
casun6 -F WinSCP 
```

Remove a package from your system:
```powershell
casun6 -R WinSCP.WinSCP 
```

List your installed packages
```powershell
casun6 -L
```

[NEW] Exclude a package / include a package previously excluded
```powershell
casun6 -E WinSCP.WinSCP # To exclude
casun6 -P WinSCP.WinSCP # To include back
```


## Screenshots

![App Screenshot](https://snipboard.io/8SzWoZ.jpg)

![App Screenshot](https://snipboard.io/eFyLWJ.jpg)

![App Screenshot](https://snipboard.io/8hgKCZ.jpg)

