<#
.Synopsis
Name: ResetLapsPassword
Version: 0.1
Developer: htcfreek (Heiko Horwedel)
Ctreated at: 11.11.2022
Github URL: https://github.com/htcfreek/ResetLapsPassword
Supported opperatingsystem: Windows 10, Windows 11
Description:
    This package triggers the reset of the LPAS password by setting the expiration time to now
	for the client on which it is running.
    By defualt this package uses the credentials of the computer account/system account.
 
Exit-Codes:
      0 : Vorgang Erfolgreich beendet.
    501 : Paket wurde gestoppt, weil es unter WinPE gestartet wurde.
    502 : Das Skript läuft nicht als "Lokal System".
    503 : Import von Modul AdmPwd (Legacy LAPS) fehlgeschlagen.
    504 : Fehler beim Senden des Reset-Befehls.

Package variables:
    xxyx : abcdefg (Deafult value: 0)

Changes (Date / Version / Autor / Aenderung):
2022-11-11 / 0.1 / htcfreek / Initial pre-release version of the package.

#>


$WindowsLapsResetImmediately = Get-EmpirumVariable -Property ResetLapsPassword.WindowsLapsResetImmediately
$WindowsLapsUseDJCredentials = Get-EmpirumVariable -Property ResetLapsPassword.WindowsLapsUseDJCredentials
$ForceLegacyLapsModule = Get-EmpirumVariable -Property ResetLapsPassword.ForceLegacyLapsModuleUsage


###### Hilfs-Funktionen
############################################################################
function IsWinPeEnvironment
{
	try
	{
		$IsKeyThere = Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\MiniNT"
		If ($IsKeyThere)
		{
			return $true
		}
		else
		{
			return $false
		}
	}
	catch
	{
		return $false
	}
}

function WriteLogInfo([string] $message)
{
    Write-Output "[ResetLapsPassword] $message";
    Send-EmpirumMessage -PxeLog $message;
}

function ExitWithCodeMessage($errorCode, $errorMessage)
{
    Send-EmpirumMessage -PxeLog $errorMessage;

    If ($errorCode -eq 0) 
    {
        $errorMessage = "[ResetLapsPassword] " + $errorMessage
        Write-Output $errorMessage;
    }
    Else
    {
        Write-Error $errorMessage;
    }

    Exit $errorCode;
}

<#
    -- Code aktuell nicht in Verwendung, da wir den Computer-Account verwenden. --
    function CreateDomainCredentialObject([string] $fqdnDomain, [string] $username, [string]$passwordAsPlaintext)
    {
        $secString = ConvertTo-SecureString $passwordAsPlaintext -AsPlainText -Force
        return New-Object System.Management.Automation.PSCredential ($fqdnDomain\$username, $secString)
    }
#>



###### Haupt-Funktion
############################################################################
function StartTriggerLapsPasswordReset()
{
    $IsDomain = Get-EmpirumVariable -Property IsDomain
    If ($IsDomain -eq "false") 
    {
        # Laps only works on AD domain-joined Systems, sow we skipp execution here.
        $message = "Warning: Client is in workgroup configuration - Reset LAPS password operation will be skipped."
        ExitWithCodeMessage -errorCode 0 -errorMessage $message;
    }

    # Write system information to log
    [string] $computerDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain().Name
    [string] $osInfo = (Get-WmiObject -class Win32_OperatingSystem).Caption + ", Build " + [System.Environment]::OSVersion.Version.Build
    WriteLogInfo -message "Computer: $env:computername - Domain: $computerDomain - OS: $osInfo"

    # Check user context
    if (-Not [System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem)
    {
        ExitWithCodeMessage -errorCode 502 -errorMessage "Error: Script must run as 'Local System'!"
    }


    # Chose LAPS-Version (Legacy LAPS or Windows LAPS) and import modules
    [bool] $IsWindowsLapsAvailable = $false
    if ((Get-Command -Name "Set-LapsADPasswordExpirationTime" -ListImported -ErrorAction SilentlyContinue) -eq $true)
    {
        WriteLogInfo -message "'Windows LAPS' module is available and will be used."
        $IsWindowsLapsAvailable = $true
    }
    else
    {
        WriteLogInfo -message "'Windows LAPS' module is not available. Falling back to 'Legacy LAPS' module."
 
        try {
            [string] $LapsLegacyModulePath = (Split-Path $PSScriptRoot -Parent) + "\AdmPwd.PSModule\AdmPwd.PS.psd1"
            WriteLogInfo -message "Importing Module 'Legacy LAPS' (AdmPwd.PS.psd1) ..."
            WriteLogInfo -message  "Using: $LapsLegacyModulePath"
            Import-Module "$LapsLegacyModulePath" -ErrorAction Stop
            WriteLogInfo -message "Module 'Legacy LAPS' (AdmPwd.PS.psd1) imported succesfully."
        } catch {
            ExitWithCodeMessage -errorCode 503 -errorMessage "Error: Module 'Legacy LAPS' (AdmPwd.PS.psd1) import failed. - $($_.Exception.Message)"
        }
    }
    
    <#
        -- Code aktuell nicht in Verwendung, da wir den Computer-Account verwenden. --
        # Get user credentials
        $DomainFqdn = Get-EmpirumVariable -Property FQDN
	    $DomJoinCredentialUser = Get-EmpirumVariable -Property "DomainJoin.DomainJoinCredentialsUser"
        $DomJoinCredentialPassword = Get-EmpirumVariable -Property "DomainJoin.DomainJoinCredentialsPassword" -Decrypt
        Write-Output "[ResetLapsPassword] Domain FQDN: $DomainFqdn"
        Write-Output "[ResetLapsPassword] DomainJoinCredentialUser: $DomJoinCredentialUser"
	    Write-Output "[ResetLapsPassword] DomainJoinCredentialPassword: ***"
        try {
            [System.Management.Automation.PSCredential] $LapsAdministrationUserCredentials = CreateDomainCredentialObject -fqdnDomain $DomainFqdn -username $DomJoinCredentialUser -passwordAsPlaintext $DomJoinCredentialPassword
        }
        catch
        {
            ExitWithCodeMessage -errorCode 503 -errorMessage "Error: Failed to create credential object for DomainJoin user. Please check the Empirum package variables for the DomainJoin package. - $($_)"
        }
    #>

    #Request password reset
    try {
        if ($IsWindowsLapsAvailable -eq $true)
        {
            # 'Windows LAPS' is the new LAPS version built-in on Windows 11 Insider Preview Build 25145 and later
            # We don't need speacial credentials here because the system account is allowed to reset the password.
            WriteLogInfo -message "Sending change request for the 'LAPS password' expiration time as user $env:Username ...."
            Set-LapsADPasswordExpirationTime -Identity $env:computername #-Credential $LapsAdministrationUserCredentials
            WriteLogInfo -message "Changing 'LAPS password' expiration time: Succefully done."
        }
        else
        {
           # We don't need speacial credentials here because the system account is allowed to reset the password.
           WriteLogInfo -message "Sending change request for the 'LAPS password' expiration time as user $env:Username ...."
           Reset-AdmPwdPassword -ComputerName $env:computername
           WriteLogInfo -message "Changing 'LAPS password' expiration time: Succefully done."
        }
    }
    catch
    {
        ExitWithCodeMessage -errorCode 504 -errorMessage "Error: Failed to change 'LAPS password' expiration time! - $($_)"
    }
    
}


function Main() {

    Write-Output "[ResetLapsPassword] Starting ResetLapsPassword package";	
    
    If (IsWinPeEnvironment)
    {
        $message = "Error: ResetLapsPassword package is running under WinPE. The execution is stopped."
        ExitWithCodeMessage -errorCode 501 -errorMessage $message;
    }

    StartTriggerLapsPasswordReset;

    Write-Output "[ResetLapsPassword] Finished ResetLapsPassword package";
}




###### Startpunkt des Powershell-Skripts
############################################################################
Main;