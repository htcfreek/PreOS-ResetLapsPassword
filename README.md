# ResetLapsPassword

<!-- Name des Repositories muss immer klein geschrieben werden. -->
<a href="https://github.com/htcfreek/preos-resetlapspassword/releases"><img src="https://img.shields.io/github/release/htcfreek/preos-resetlapspassword?label=stable+release"/></a> <a href="https://github.com/htcfreek/preos-resetlapspassword/releases/latest"><img src="https://img.shields.io/github/release/htcfreek/preos-resetlapspassword?include_prereleases&label=latest+release"/></a> <a href="LICENSE.md"><img src="https://img.shields.io/github/license/htcfreek/preos-resetlapspassword" /></a>

<a href="https://github.com/htcfreek/preos-resetlapspassword/releases"><img src="https://img.shields.io/github/downloads/htcfreek/preos-resetlapspassword/total?label=Downloads"/></a> <a href="https://github.com/htcfreek/preos-resetlapspassword/stargazers"><img src="https://img.shields.io/github/stars/htcfreek/preos-resetlapspassword" /></a> <a href="https://github.com/htcfreek/preos-resetlapspassword/watchers"><img src="https://img.shields.io/github/watchers/htcfreek/preos-resetlapspassword" /></a> <a href="https://github.com/htcfreek/preos-resetlapspassword/network/members"><img src="https://img.shields.io/github/forks/htcfreek/preos-resetlapspassword" /></a>

A PreOS-Package for Matrix42 Empirum to reset the LAPS password of a computer on reinstall.

The package works with Windows 10 (Build 19041 and higher) or Windows 11. Legacy Microsoft LAPS and Windows LAPS are supported. An up to date Empirum WinPE environment (at least 1.8.12) and PowerShell 5.1 are required!

For more details about the LAPS modes, supported Operating Systems and configuration see the [LAPS configuration table](#LAPS-configuration-requirements) below.

The package has the Legacy LAPS PowerShell module from the Microsoft LAPS installer included. (Link to the installer: <https://www.microsoft.com/en-us/download/details.aspx?id=46899>)

## Features

- Supports Windows LAPS with Azure AD and local AD.
- Supports legacy Microsoft LAPS with local AD and the [legacy emulation mode of Windows LAPS](https://learn.microsoft.com/windows-server/identity/laps/laps-scenarios-legacy).
- Supports coexistence of legacy Microsoft LAPS and Windows LAPS as long as they manage different accounts. ([More information.](https://github.com/MicrosoftDocs/windowsserverdocs/issues/6961#issuecomment-1382908222))
- Support for setting the expiration time¹ and for resetting the password immediately.
- Automatic detection of the client's LAPS configuration based on GPOs, CSP policies and Registry values.
- Using the computer account credentials for password reset.
- Skipping package execution if the computer is not joined to Azure AD or a local domain.
- LAPS can be defined as mandatory using a package variable. (See [package variables](#package-variables) for more details.)

_¹) Not supported in Windows LAPS with Azure AD as backup target, because of how LAPS works in this case. ([More information.](https://learn.microsoft.com/windows-server/identity/laps/laps-scenarios-azure-active-directory#rotate-the-password))_

## Download and Usage

1. Download the archive from [here](http://github.com/htcfreek/PreOS-ResetLapsPassword/releases).
2. Please extract the downloaded archive to `%EmpirumServer%\Configurator$\PackageStore\PreOSPackages` and import the package into your Software Depot (Matrix42 Management Console > Configuration > Depot).
3. Move the package within the depot register "Matrix42 PreOS Packages" after the "DomainJoin" package and activate it for deployment ("Ready to install").
4. Then you can assign the package and set the package variables if you want to change the default behavior.

### Package variables

- **IntuneSyncTimeout : 10 (default) or custom value.**
    <br />Number of minutes to wait for the first Intune policy sync cycle.
- **LapsIsMandatory : 0 (default) or 1**
    <br />If set to 1 the package will fail if LAPS is not enabled/configured.
- **ResetImmediately : 0 (default) or 1**
    <br />If set to 1 the password is reset immediately instead of changing the expiration time.
    <br />(Enforced automatically in Azure AD environments, because changing the expiration time is not supported in this scenario.)

### LAPS configuration requirements

Mode | Supported OS | Install requirements | Configuration requirements | ⚠ Important ⚠
------------ | ------------- | ------------- | ------------- | -------------
Legacy Microsoft LAPS | Up to the newest Windows version. | MS LAPS (AdmPwd) CSE | MS LAPS (AdmPwd) policies |
Windows LAPS | At least Windows 10&sup1; or Windows 11 21H2&sup1;. | built-in feature | Windows LAPS GPO/CSP/Registry values |
Windows LAPS in legacy MS LAPS emulation mode | At least Windows 10&sup1; or Windows 11 21H2&sup1;. | built-in feature | MS LAPS (AdmPwd) policies | - MS LAPS (AdmPwd) CSE must not be installed.<br />- Windows LAPS configuration must not be set.
Legacy Microsoft LAPS & Windows LAPS running parallel | At least Windows 10&sup1; or Windows 11 21H2&sup1;. | - MS LAPS (AdmPwd) CSE<br />- Windows LAPS as built-in feature. | - MS LAPS (AdmPwd) policies<br />- Windows LAPS GPO/CSP/Registry values | Both LAPS version have to manage different user accounts.

_&sup1; For Windows 10, Windows 11 21H1 and Windows 11 22H2 the Update from April 11 2023 is required._

## Support

⚠ The provided code/content in this repository isn't developed by "Matrix42 AG". It was created by the repository owner. This means that the company "Matrix42 AG" isn't responsible to answer any support requests regarding the tools, scripts and packages in this repository in any way!

If you have any problems or want to suggest a new feature please [fill a bug in this repository](https://github.com/htcfreek/PreOS-ResetLapsPassword/issues/new).

## Credits

This repository includes scripts (and other files) that where created while my day to day job work. I want to say thank you to my employer who allows me to share them with you (the community).

A big thank you to Mr. Jochen Schmitt, who mentioned this package in his [blog](https://www.wpm-blog.de/) and helped me with testing the initial release.

## Disclaimer

Product names and company names are trademarks (™) or registered (®) trademarks of their respective holders. Use of them does not imply any affiliation with or endorsement by them.

## License

This Repository is licensed to you under the MIT license.<br />
See the [LICENSE](LICENSE.md) file in the project root for more information.
