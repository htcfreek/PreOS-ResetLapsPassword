## Repo name: PreOS-ResetLapsPassword
## Repo owner: htcfreek (Heiko Horwedel) - https://gtihub.com/htcfreek
## Repo URL: https://github.com/htcfreek/PreOS-ResetLapsPassword
########################################


PACKAGE INFORMATION
-------------------
A PreOS-Package for Matrix42 Empirum that can reset the LAPS password of a computer on reinstall.

You can use the package with Windows 11 (Windows LAPS & Legacy LAPS) and Windows 10 (Legacy LAPS).
The package requires an up to date Empirum WinPE environment (at least 1.8.12) and PowerShell 5.1!

The package has the Legacy LAPS PowerShell module form the Microsoft LAPS installer included. (Link to the installer: https://www.microsoft.com/en-us/download/details.aspx?id=46899)

FEATURES:
- Support for both LAPS versions (Legacy & Windows).
- Immediate password reset with Windows LAPS.
- Using the computer account credentials for password reset.
- Using the domain join credentials when setting only the expiration date under Windows LAPS.
- Forcing the usage of Legacy LAPS if Windows LAPS is available too.

PACKAGE VARIABLES:
- WindowsLapsResetImmediately : 0 (default) or 1
	Reset the password immediately instead of changing the expiration time.
	(Only supported with Windows LAPS on Win11 IP Build 25145 and later.)
- WindowsLapsUseDJCredentials : 0 (default) or 1
	Use the DomainJoin package user credentials instead of the computer account context.
	(Only supported with Windows LAPS on Win11 IP Build 25145 and later. "WindowsLapsResetImmidiately" has to be set to 0.)
- ForceLegacyLapsModuleUsage : 0 (default) or 1
	Enforce the usage of the Legacy LAPS (Adm.Pwd) module included in this PreOS package.
	(On Windows 11 IP Build 25145 and later the built-in Windows LAPS module will be used by default.)


DOWNLOAD AND USAGE
------------------
Download the files form https://github.com/htcfreek/preos-resetlapspassword/releases.

After downloading the release file, please extract its content to %EmpirumDir%\Configurator$\PackageStore\PreOSPackages and import the package in your Software Depot. Then you can assign the package and set the package variables if you want to change the default behaviour.


SUPPORT
-------
⚠ The provided code/content in this repository isn't developed by "Matrix42 AG". It was created by the repository owner. This means that the company "Matrix42 AG" isn't responsible to answer any support requests regarding the tools, scripts and packages in this repository in any way!

If you have any problems or want to suggest a new feature please fill a bug in this repository under https://github.com/htcfreek/PreOS-ResetLapsPassword/issues/new.


CREDITS
-------
This repository includes scripts (and other files) that where created while my day to day job work. I want to say thank you to my employer who allows me to share them with you (the community).


DISCLAIMER
----------
All named product and company names are trademarks (™) or registered (®) trademarks of their respective holders. Use of them does not imply any affiliation with or endorsement by them.


LICENSE
-------
This Repository is licensed to you under the MIT license.
See the LICENSE.md file in the same directory for more information.
