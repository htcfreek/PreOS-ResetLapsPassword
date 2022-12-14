<#
Name: ResetLapsPassword
Version: 0.1
Developer: htcfreek (Heiko Horwedel)
Ctreated at: 20.11.2022
Github URL: https://github.com/htcfreek/PreOS-ResetLapsPassword

Systems requirements:
    - Windows 10 or Windows 11
    - Empirum WinPE environment (at least 1.8.12)
    - PowerShell 5.1

Description:
    This package triggers the reset of the LPAS password by setting the expiration time to now
	for the client on which it is running. (With Windows LAPS it is possible to reset the password immediately.)
    By defualt this package uses the credentials of the computer account/system account. (But when setting the expiration date with Windows LAPS you can use the DomianJoin package credentials instead.)
 
Package variables:
    - WindowsLapsResetImmediately : 0 (default) or 1
        Reset the password immediately instead of changing the expiration time.
        (Only supported with Windows LAPS on Win11 IP Build 25145 and later.)
    - WindowsLapsUseDJCredentials : 0 (default) or 1
        Use the DomainJoin package user credentials instead of the computer account context.
        (Only supported with Windows LAPS on Win11 IP Build 25145 and later. "WindowsLapsResetImmidiately" has to be set to 0.)
    - ForceLegacyLapsModuleUsage : 0 (default) or 1
        Enforce the usage of the Legacy LAPS (Adm.Pwd) module included in this PreOS package.
        (On Windows 11 IP Build 25145 and later the built-in Windows LAPS module will be used by default.)

Exit-Codes:
      0 : Script executed successful.
    501 : Package execution has stopped, because it is running in WinPE.
    502 : The script is not executed as "local system".
    503 : Import of the modul AdmPwd (Legacy LAPS) has failed.
    504 : Error on executing the reset command.
    550 : A package variable is not set and we have to abort.

Changes (Date / Version / Autor / Aenderung):
2022-11-11 / 0.1 / htcfreek / Initial pre-release version of the package.

#>




###### Helper functions
############################################################################
function IsWinPeEnvironment
{
    # Function: IsWinPeEnvironment
    # Returns: "Tru" if WinPE and "False" if not.
	try
	{
        return (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\MiniNT")
	}
	catch
	{
		return $false
	}
}

function WriteLogInfo([string] $message)
{
    Write-Host "[ResetLapsPassword] $message";
    Send-EmpirumMessage -PxeLog $message;
}

function ExitWithCodeMessage($errorCode, $errorMessage)
{
    Send-EmpirumMessage -PxeLog $errorMessage;

    If ($errorCode -eq 0) 
    {
        $errorMessage = "[ResetLapsPassword] " + $errorMessage
        Write-Host $errorMessage;
    }
    Else
    {
        Write-Error $errorMessage;
    }

    Exit $errorCode;
}

function ReadEmpirumVariable ([string] $varName, [Switch] $isPwd, [Switch] $returnSecureString, [string]$defaultValue)
{
    # Function: ReadEmpirumVariable
    # Input:    $varName = Variable name.
    #           $isPwd = If set the variable value is hidden in the logs.
    #           $returnSecureString = If set the password is returned as "SecureString".
    #           $defaultValue = Value to return if variable is empty. If not set, the script aborts on an empty variable.
    # Return:   The variable content as plain text or SecureString.

    $varContent = Get-EmpirumVariable -Property $varName -Decrypt $isPwd
    $isVarContentEmpty = (($null -eq $varContent) -or ($varContent -eq "") -or ($varContent -eq " "))

    $logContent = if ($isPwd -and ($isVarContentEmpty -eq $false)) {"*****"} Else {$varContent}
    Write-Host "[ResetLapsPassword] Variable '$($varName)': $($logContent)"

    if (-Not $isVarContentEmpty) 
    {
        if ($isPwd -and $returnSecureString) {
            return ConvertTo-SecureString -String $varContent -AsPlainText -Force
        }
        else {
            return $varContent
        }
    }
    elseif (-Not [string]::IsNullOrWhiteSpace($defaultValue))
    {
        Write-Host "[ResetLapsPassword] Warning: Variable '$($varName)' is not set! The default value is used: $($defaultValue)"
        return $defaultValue
    }
    else
    {
        ExitWithCodeMessage -errorCode 550 -errorMessage "Error: The variabel '$($varName)' is not set. Abort execution and exit script."
    }
}



###### Main functions
############################################################################
function TriggerLapsPasswordReset()
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
    WriteLogInfo -message "Computer: $env:computername - Domain: $computerDomain - User: $env:Username - OS: $osInfo"

    # Check user context
    if (-Not [System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem)
    {
        ExitWithCodeMessage -errorCode 502 -errorMessage "Error: Script must run as 'Local System'!"
    }

    # Read package variables
    $WindowsLapsResetImmediately = ReadEmpirumVariable -varName ResetLapsPassword.WindowsLapsResetImmediately -defaultValue 0
    $WindowsLapsUseDJCredentials = ReadEmpirumVariable -varName ResetLapsPassword.WindowsLapsUseDJCredentials -defaultValue 0
    $ForceLegacyLapsModule = ReadEmpirumVariable -varName ResetLapsPassword.ForceLegacyLapsModuleUsage -defaultValue 0

    # Chose LAPS-Version (Legacy LAPS or Windows LAPS) and import modules
    # 'Windows LAPS' is the new LAPS version built-in on Windows 11 Insider Preview Build 25145 and later
    if ($Null -eq (Get-Command -Name "Set-LapsADPasswordExpirationTime" -ListImported -ErrorAction SilentlyContinue))
    {
        # Windows LAPS is not available.
        WriteLogInfo -message "'Windows LAPS' module is not available. Falling back to 'Legacy LAPS' module."
        [bool] $useAvailableWindowsLaps = $false
    }
    elseif ($ForceLegacyLapsModule)
    {
        # Using the Legacy LAPS module is enforced.
        WriteLogInfo -message "Using the 'Legacy LAPS' module is enforced by package variable."
        [bool] $useAvailableWindowsLaps = $false
    }
    else
    {
        # Windows LAPS is available and should be used.
        WriteLogInfo -message "'Windows LAPS' module is available and will be used."
        [bool] $useAvailableWindowsLaps = $true
    }

    # Import legacy LAPS module if required.
    if (-Not $useAvailableWindowsLaps)
    {
        try {
            [string] $lapsLegacyModulePath = (Split-Path $PSScriptRoot -Parent) + "\AdmPwd.PSModule\AdmPwd.PS.psd1"
            WriteLogInfo -message "Importing Module 'Legacy LAPS' (AdmPwd.PS.psd1) ..."
            Write-Host "[ResetLapsPassword] Module path: $($lapsLegacyModulePath)"
            Import-Module "$lapsLegacyModulePath" -ErrorAction Stop
            WriteLogInfo -message "Module 'Legacy LAPS' (AdmPwd.PS.psd1) imported succesfully."
        } catch {
            ExitWithCodeMessage -errorCode 503 -errorMessage "Error: Module 'Legacy LAPS' (AdmPwd.PS.psd1) import failed. - $($_.Exception.Message)"
        }
    }

    # Get user credentials for changing expiration adte with Windows LAPS
    if ($useAvailableWindowsLaps -and ($WindowsLapsResetImmediately -eq $false) -and $WindowsLapsUseDJCredentials)
    {        
        $DomainFqdn = ReadEmpirumVariable -varName FQDN
        $DomJoinCredentialUser = ReadEmpirumVariable -varName DomainJoin.DomainJoinCredentialsUser
        $DomJoinCredentialPassword = ReadEmpirumVariable -varName DomainJoin.DomainJoinCredentialsPassword -isPwd -returnSecureString
        try {
            [PSCredential] $lapsAdministrationUserCredentials = New-Object PSCredential ("$DomainFqdn\$DomJoinCredentialUser", $DomJoinCredentialPassword)
            Clear-Variable -Name "DomainFqdn"
            Clear-Variable -Name "DomJoinCredentialUser"
            Clear-Variable -Name "DomJoinCredentialPassword"
        }
        catch
        {
            ExitWithCodeMessage -errorCode 503 -errorMessage "Error: Failed to create credential object for DomainJoin user. Please check the Empirum package variables for the DomainJoin package. - $($_)"
        }
    }
    
    #Request password reset
    if ($useAvailableWindowsLaps -and $WindowsLapsResetImmediately)
    {
        # Use Windows LAPS and reset immediately.
        # 'Windows LAPS' is the new LAPS version built-in on Windows 11 Insider Preview Build 25145 and later.
        try
        {
            # We don't need speacial credentials here because the system account is allowed to reset the password.
            WriteLogInfo -message "Resetting the LAPS password immediatly as user $env:Username ...."
            Reset-LapsPassword
            WriteLogInfo -message "Password reset: Succefully done."
        }
        catch
        {
            ExitWithCodeMessage -errorCode 504 -errorMessage "Error: Failed to reset the LAPS password! - $($_)"
        }
    }
    elseif ($useAvailableWindowsLaps -and $WindowsLapsUseDJCredentials)
    {
        # Use Windows LAPS and set expiration time as DomainJoin user account.
        # 'Windows LAPS' is the new LAPS version built-in on Windows 11 Insider Preview Build 25145 and later.
        try
        {
            WriteLogInfo -message "Sending change request for the LAPS password expiration time as user $($lapsAdministrationUserCredentials.UserName) ...."
            Set-LapsADPasswordExpirationTime -Identity $env:computername -Credential $lapsAdministrationUserCredentials
            WriteLogInfo -message "Changing LAPS password expiration time: Succefully done."
        }
        catch
        {
            ExitWithCodeMessage -errorCode 504 -errorMessage "Error: Failed to change LAPS password expiration time! - $($_)"
        }

    }
    elseif ($useAvailableWindowsLaps)
    {
        # Use Windows LAPS and set expiration time as computer account.
        # 'Windows LAPS' is the new LAPS version built-in on Windows 11 Insider Preview Build 25145 and later.
        try
        {
            # We don't need speacial credentials here because the system account is allowed to reset the password.
            WriteLogInfo -message "Sending change request for the LAPS password expiration time as user $env:Username ...."
            Set-LapsADPasswordExpirationTime -Identity $env:computername
            WriteLogInfo -message "Changing LAPS password expiration time: Succefully done."
        }
        catch
        {
            ExitWithCodeMessage -errorCode 504 -errorMessage "Error: Failed to change LAPS password expiration time! - $($_)"
        }

    }
    else
    {
        # Use Legacy LAPS.
        try
        {
           # We don't need speacial credentials here because the system account is allowed to reset the password.
           WriteLogInfo -message "Sending change request for the LAPS password expiration time as user $env:Username ...."
           Reset-AdmPwdPassword -ComputerName $env:computername
           WriteLogInfo -message "Changing LAPS password expiration time: Succefully done."
        }
        catch
        {
            ExitWithCodeMessage -errorCode 504 -errorMessage "Error: Failed to change LAPS password expiration time! - $($_)"
        }

    }  
}


function Main() {

    Write-Output "[ResetLapsPassword] Starting ResetLapsPassword package";	
    
    If (IsWinPeEnvironment)
    {
        $message = "Error: ResetLapsPassword package is running under WinPE. The execution is stopped."
        ExitWithCodeMessage -errorCode 501 -errorMessage $message;
    }

    TriggerLapsPasswordReset;

    Write-Output "[ResetLapsPassword] Finished ResetLapsPassword package";
}




###### Entry point of the Powershell script
############################################################################
Main;