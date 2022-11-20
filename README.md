
<!-- Name des Repositorys muss immer klein geschrieben werden. -->
<a href="https://github.com/htcfreek/preos-resetlapspassword/releases/latest"><img src="https://img.shields.io/github/release/htcfreek/preos-resetlapspassword" /></a> <a href="https://github.com/htcfreek/preos-resetlapspassword/releases/latest"><img src="https://img.shields.io/github/downloads/htcfreek/preos-resetlapspassword/total?label=Downloads" /></a> <a href="LICENSE.md"><img src="https://img.shields.io/github/license/htcfreek/preos-resetlapspassword" /></a>

<a href="https://github.com/htcfreek/preos-resetlapspassword/stargazers"><img src="https://img.shields.io/github/stars/htcfreek/preos-resetlapspassword" /></a> <a href="https://github.com/htcfreek/preos-resetlapspassword/watchers"><img src="https://img.shields.io/github/watchers/htcfreek/preos-resetlapspassword" /></a> <a href="https://github.com/htcfreek/preos-resetlapspassword/network/members"><img src="https://img.shields.io/github/forks/htcfreek/preos-resetlapspassword" /></a>


# ResetLapsPassword

A PreOS-Package for Matrix42 Empirum that can reset the LAPS password of a computer on reinstall.

You can use the package with Windows 11 (Windows LAPS & Legacy LAPS) and Windows 10 (Legacy LAPS).
The package requires an up to date Empirum WinPE environment (at least 1.8.12) and PowerShell 5.1!

The package has the Legacy LAPS PowerShell module from the Microsoft LAPS installer included. (Link to the installer: https://www.microsoft.com/en-us/download/details.aspx?id=46899)

### Features
- Support for both LAPS versions (Legacy & Windows).
- Immediate password reset with Windows LAPS.
- Supports AzureAD for resetting the password immediately.
- Using the computer account credentials for password reset.
- Using the domain join credentials when setting only the expiration date under Windows LAPS.
- Forcing the usage of Legacy LAPS if Windows LAPS is available too.
- Skipping package execution if the Computer object in Empirum is not configured for Domain join.

### Package variables

- **WindowsLapsResetImmediately	:	0 (default) or 1**
   <br />Reset the password immediately instead of changing the expiration time.<br />(Only supported with Windows LAPS on Win11 IP Build 25145 and later.)
- **WindowsLapsUseDJCredentials	:	0 (default) or 1**
   <br />Use the DomainJoin package user credentials instead of the computer account context.<br />(Only supported with Windows LAPS on Win11 IP Build 25145 and later. "WindowsLapsResetImmidiately" has to be set to 0.)
- **ForceLegacyLapsModuleUsage	:	0 (default) or 1**
   <br />Enforce the usage of the Legacy LAPS (Adm.Pwd) module included in this PreOS package.<br />(On Windows 11 IP Build 25145 and later the built-in Windows LAPS module will be used by default.)

### External variables
To use the domain join credentials from the DomainJoin package, the following external variables are used:
- FQDN
- DomainJoin.DomainJoinCredentialsUser		: User with the permissions to join the computer to your Domain.
- DomainJoin.DomainJoinCredentialsPassword 	: Password of the join user.


# Download and Usage
1. Download the files form [here](http://github.com/htcfreek/preos-resetlapspassword/release/latest).
2. Please extract the downloaded file to `%EmpirumServer%\Configurator$\PackageStore\PreOSPackages` and import the package in your Software Depot (Matrix42 Management Console > Configuration > Depot).
3. Move the package in the depot register "Matrix42 PreOS Packages" after the DomainJoin package and activate it for deployment ("Ready to install").
4. Then you can assign the package and set the package variables if you want to change the default behaviour.


# Support
⚠ The provided code/content in this repository isn't developed by "Matrix42 AG". It was created by the repository owner. This means that the company "Matrix42 AG" isn't responsible to answer any support requests regarding the tools, scripts and packages in this repository in any way!

If you have any problems or want to suggest a new feature please fill a bug in this repository under https://github.com/htcfreek/PreOS-ResetLapsPassword/issues/new.


# Credits
This repository includes scripts (and other files) that where created while my day to day job work. I want to say thank you to my employer who allows me to share them with you (the community).

A big thank you to Mr. Jochen Schmitt, who mentioned this package in his [blog](https://www.wpm-blog.de/) and helped me with testing the initial release.


# Disclaimer
Product names and company names are trademarks (™) or registered (®) trademarks of their respective holders. Use of them does not imply any affiliation with or endorsement by them.


# License
This Repository is licensed to you under the MIT license.<br />
See the [LICENSE](LICENSE.md) file in the project root for more information.
