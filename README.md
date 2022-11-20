
<!-- Name des Repositorys muss immer klein geschrieben werden. -->
<a href="https://github.com/htcfreek/preos-resetlapspassword/releases/latest"><img src="https://img.shields.io/github/release/htcfreek/preos-resetlapspassword" /></a> <a href="https://github.com/htcfreek/preos-resetlapspassword/releases/latest"><img src="https://img.shields.io/github/downloads/htcfreek/preos-resetlapspassword/total?label=Downloads" /></a> <a href="LICENSE.md"><img src="https://img.shields.io/github/license/htcfreek/preos-resetlapspassword" /></a>

<a href="https://github.com/htcfreek/preos-resetlapspassword/stargazers"><img src="https://img.shields.io/github/stars/htcfreek/preos-resetlapspassword" /></a> <a href="https://github.com/htcfreek/preos-resetlapspassword/watchers"><img src="https://img.shields.io/github/watchers/htcfreek/preos-resetlapspassword" /></a> <a href="https://github.com/htcfreek/preos-resetlapspassword/network/members"><img src="https://img.shields.io/github/forks/htcfreek/preos-resetlapspassword" /></a>


# PreOS-ResetLapsPassword

A PreOS-Package for Matrix42 Empirum that can reset thet LAPS password of a computer on reinstall.

You can use the package with Windows 11 (Windows LAPS & Legacy LAPS) and Windows 10 (Legacy LAPS)
The packeage requires an up to date Empirum WinPE environment (at least 1.8.12) and PowerShell 5.1! 

### Features
- Support for both LAPS versions (Legacy & Windows).
- Immidiate password reset with Windows LAPS.
- Using the computer account credentials for password reset.
- Using the domain join credentials when setting only the expiration date under Windows LAPS.
- Forcing the usage of Legacy LAPS if Windows LAPS is available too.

### Package variables

| Variable | Values | Behavior | Note |
|--------------|-----------|------------|------------|
| WindowsLapsResetImmediately | 0 (default) or 1 | Reset the password immidiatly instead of chnaging the expiration time. | Only supported with Windows LAPS on Win11 IP Build 25145 and later. |
| WindowsLapsUseDJCredentials | 0 (default) or 1 | Use the DomainJoin package user credentials instead of the computer account context. | (Only supported with Windows LAPS on Win11 IP Build 25145 and later. "WindowsLapsResetImmidiately" has to be set to 0.) |
| ForceLegacyLapsModuleUsage | 0 (default) or 1 | Enforce the usgae of the Legacy LAPS (Adm.Pwd) module included in this PreOS package. | On Windows 11 IP Build 25145 and later the built-in Windows LAPS module will be used by default. |


## Download and Usage
Download the files form [here](http://github.com/htcfreek/preos-resetlapspassword/release/latest).
  
After downloading the release file, please extract its content to `%EmpirumDir%\Configurator$\PackageStore\PreOSPackages` and import the package in your Software Depot. Then you can assign the package and set the package variables if you want to change the default behaviour.



## Support
⚠ The provided code/content in this repository isn't developed by "Matrix42 AG". It was created by the repository owner. This means that the company "Matrix42 AG" isn't responsible to answer any support requests regarding the tools, scripts and packages in this repository in any way!

If you have any problems or want to suggest a new feature please fill a bug in this repository under https://github.com/htcfreek/PreOS-ResetLapsPassword/issues/new.



# Credits
This repository includes scripts (and other files) that where created while my day to day job work. I want to say thank you to my employer who allows me to share them with you (the community).


# Disclaimer
All named product and company names are trademarks (™) or registered (®) trademarks of their respective holders. Use of them does not imply any affiliation with or endorsement by them.

# License
This Repository is licensed to you under the MIT license.<br />
See the [LICENSE](LICENSE.md) file in the project root for more information.
