<#
Name: ResetLapsPassword
Version: 0.2-prerelease
Developer: htcfreek (Heiko Horwedel)
Created at: 25.01.2023
Github URL: https://github.com/htcfreek/PreOS-ResetLapsPassword

Systems requirements:
    - Windows 10 (Build 19041 or higher) or Windows 11
    - Empirum WinPE environment (at least 1.8.12)
    - PowerShell 5.1
    - Legacy Microsoft LAPS and/or Windows LAPS

Description:
    This package triggers the reset of the LAPS password for the client on which it is running.
    (On Azure environments only the immediate reset is supported.)
    By default this package uses the credentials of the computer account/system account.
 
Package variables:
    - IntuneSyncTimeout : 10 (default) or custom value.
        Number of minutes to wait for the first Intune policy sync cycle.
    - LapsIsMandatory : 0 (default) or 1
        If set to 1 the package will fail if LAPS is not enabled/configured.
    - ResetImmediately : 0 (default) or 1
        If set to 1 the password is reset immediately instead of changing the expiration time.
        (Enforced automatically in Azure AD environments, because changing the expiration time is not supported in this scenario.)

Exit-Codes:
      0 : Script executed successful.
    501 : Package execution has stopped, because it is running in WinPE.
    502 : Operating System is not supported.
    503 : The script is not executed as "local system".
    504 : Reboot required to finish domain join.
    505 : LAPS is disabled, but mandatory.
    506 : Both legacy MS LAPS and Windows LAPS are enabled for the same user.
    507 : Legacy MS LAPS should be used and the CSE is missing.
    508 : Windows LAPS should be used and is not installed/supported.
    509 : Import of the module AdmPwd (legacy Microsoft LAPS) has failed.
    510 : Windows LAPS user does not exist.
    511 : Windows LAPS password reset failed.
    512 : Legacy Microsoft LAPS password reset failed.

Changes (Date / Version / Author / Change):
2022-11-11 / 0.1 / htcfreek / Initial pre-release version of the package.
2023-01-25 / 0.2 / htcfreek / Complete rewrite of the package with changed variables and behavior.

#>




###### Helper functions
############################################################################

function ConvertTo-YesNo([bool]$value)
{
    if ($value -eq $true) {
        return "Yes"
    }
    else {
        return "No"
    }
}

function IsWinPeEnvironment
{
    # Function: IsWinPeEnvironment
    # Returns: "True" if WinPE and "False" if not.
    try
    {
        return (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\MiniNT")
    }
    catch
    {
        return $false
    }
}

function WriteLogInfo([string] $Message)
{
    Write-Host "[ResetLapsPassword] $message";
    Send-EmpirumMessage -PxeLog $message;
}

function WriteLogDebug([string] $Message)
{
    Write-Host "[ResetLapsPassword] $message" -ForegroundColor Magenta;
}

function ExitWithCodeMessage($errorCode, $errorMessage)
{
    If ($errorCode -eq 0)
    {
        WriteLogInfo -Message $errorMessage;
    }
    Else
    {
        Send-EmpirumMessage -PxeLog $errorMessage;
        Write-Error "[ResetLapsPassword] $errorMessage";
    }

    Exit $errorCode;
}

function ReadEmpirumVariable ([string] $varName, [Switch] $isPwd, [Switch] $returnSecureString, [Switch]$isBoolean, [string]$defaultValue)
{
    # Function: ReadEmpirumVariable
    # Input:    $varName = Variable name.
    #           $isPwd = If set the variable value is hidden in the logs.
    #           $returnSecureString = If set the password is returned as "SecureString".
    #           $isBoolean = If set the value is converted to $true (<value> == 1) or $false (<value> != 1).
    #           $defaultValue = Value to return if variable is empty. If not set, the script aborts on an empty variable.
    # Return:   The variable content as plain text or SecureString.

    $varContent = Get-EmpirumVariable -Property $varName -Decrypt $isPwd
    $isVarContentEmpty = (($null -eq $varContent) -or ($varContent -eq "") -or ($varContent -eq " "))

    $logContent = if ($isPwd -and ($isVarContentEmpty -eq $false)) {"*****"} Else {$varContent}
    WriteLogDebug -Message "Variable '$($varName)': $($logContent)"

    if (-Not $isVarContentEmpty)
    {
        if ($isPwd -and $returnSecureString) {
            return ConvertTo-SecureString -String $varContent -AsPlainText -Force
        }
        elseif ($isBoolean) {
            return ($varContent -eq "1")
        }
        else {
            return $varContent
        }
    }
    elseif (-Not [string]::IsNullOrWhiteSpace($defaultValue))
    {
        WriteLogDebug -Message "WARNING: Variable '$($varName)' is not set! The default value is used: $($defaultValue)"
        if ($isBoolean) {
            return $defaultValue -eq "1"
        }
        else {
            return $defaultValue
        }
    }
    else
    {
        ExitWithCodeMessage -errorCode 550 -errorMessage "ERROR: The variable '$($varName)' is not set. Abort execution and exit script."
    }
}

function Confirm-RegValueIsDefined([string]$RegPath, [string]$RegValueName)
{
    # Function: Confirm-RegValueIsDefined
    # The function checks wether a value exists and if it has a value other than "$null", "empty" or "white space".
    # Input parameters:
    #	- [string]$RegPath : Path to Registry key.
    #	- [string]$RegValueName : Name of Registry value.
    # Returns a boolean value.

    if (Test-Path -Path $RegPath -ErrorAction SilentlyContinue)
    {
        $regPathItem = Get-ItemProperty -Path $RegPath
        if ($null -ne $regPathItem)
        {
            if (Get-Member -InputObject $regPathItem -Name $RegValueName)
            {
                [string] $value = Get-ItemPropertyValue -Path $RegPath -Name $RegValueName
                if (-Not [string]::IsNullOrWhiteSpace($value))
                {
                    return $true
                }
            }
        }
    }

    # If there is no valid value:
    return $false
}




###### Main functions
############################################################################

function Update-ClientMgmtConfiguration([int]$IntuneSyncTimeout)
{
    # Function: Update-ClientMgmtConfiguration
    # The function checks which management systems are used and updates the management policies.
    # Input parameter:
    #    - [int]$IntuneSyncTimeout : Minutes to wait for the initial sync of Intune/MDM policies.
    # Return value: <$true> = Joined to Azure or local AD; <$false> = Not joined to an AD.

    # Convert timeout to seconds.
    $IntuneSyncTimeout *= 60

    # Debug/Log information
    WriteLogDebug "Updating client management information ..."

    # First check if there is a local Domain Join pending: The key "...\Services\NetlogonJoinDomain" or "...\Services\Netlogon\AvoidSpnSet" does exist.
    # - See also: https://www.powershellgallery.com/packages/PendingReboot/0.9.0.6/Content/pendingreboot.psm1
    $regNetlogon = Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon" -Name
    if (($regNetlogon -contains 'JoinDomain') -or ($regNetlogon -contains 'AvoidSpnSet'))
    {
        ExitWithCodeMessage -errorCode 504 -errorMessage "ERROR: Pending reboot from an Active Directory domain join detected! - Rebooting client ..."
    }

    # If the device is joined to a local Active Directory, then update the GPOs.
    [bool]$isActiveDirectory = (Get-WmiObject -Class Win32_Computersystem -Property PartOfDomain).PartOfDomain
    [bool]$isWorkgroup = (-Not $isActiveDirectory)
    if ($isActiveDirectory)
    {
        WriteLogInfo "Client is joined to a local Active Directory. - Updating Group Policies ..."
        & gpupdate.exe /force
    }

    # Is the device joined to Azure AD?
    # - See also: https://nerdymishka.com/articles/azure-ad-domain-join-registry-keys/
    [bool]$isAzureAD = Confirm-RegValueIsDefined -RegPath "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo\*" -RegValueName "TenantId"

    # Is the device enrolled in Intune/MDM?
    # (We read the Enrolment ID from Registry and validate it against two different places.)
    # - See also: https://www.anoopcnair.com/windows-10-intune-mdm-support-help-1/
    try {
        [string]$regEnrolmentID = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked" -Name
        if ([string]::IsNullOrEmpty($regEnrolmentID)) {throw}
        if (-Not (Test-Path "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\$($regEnrolmentID)")) {throw}
        if (-Not (Test-Path -Path "C:\ProgramData\Microsoft\DMClient\$($regEnrolmentID)")) {throw}

        # If we can find the guid and both paths, the device is enrolled.
        [bool]$isIntuneMDM = $true
    }
    catch
    {
        [bool]$isIntuneMDM = $false
    }

    # If the device is joined to Azure or Intune, wait for the initial Intune policy sync.
    If ($isAzureAD -or $isIntuneMDM)
    {
        WriteLogInfo "Client is joined to Azure AD and/or Intune. - Because it might be a newly enrolled device, we are waiting $($IntuneSyncTimeout / 60) minutes for the first policy sync ..."
        Start-Sleep -Seconds $IntuneSyncTimeout
    }

    # Write the summary to log.
    WriteLogInfo "Management summary: Azure AD joined = $(ConvertTo-YesNo $isAzureAD), Domain joined = $(ConvertTo-YesNo $isActiveDirectory), Workgroup joined = $(ConvertTo-YesNo $isWorkgroup), Intune enrolled = $(ConvertTo-YesNo $isIntuneMDM)"

    # Return result (<$true> if joined and <$false> if not.)
    return ($isAzureAD -or $isActiveDirectory)
}


function Get-LegacyLapsState()
{
    # Function: Get-LegacyLapsState
    # The function checks if the legacy Microsoft LAPS CSE is installed on this client and if the legacy Microsoft LAPS policy is configured.
    # Legacy LAPS CSE={D76B9641-3288-4f75-942D-087DE603E3EA}
    # Legacy LAPS Policy=HKLM\Software\Policies\Microsoft Services\AdmPwd!AdmPwdEnabled
    # Returns an object with the following members:
    #    - Installed : Yes=$true, No=$false (bool value)
    #    - Enabled : Yes=$true, No=$false (bool value)
    #    - UserName
    #    - UserExists : Yes=$true, No=$false, <Builtin Admin>=$true

    # Initialize return object variable
    $resultData = [PSCustomObject]@{
        Installed = $false
        Enabled = $false
        UserName = ""
        UserDoesExist=$true
    }

    # Is CSE installed?
    $regKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\GPExtensions\{D76B9641-3288-4f75-942D-087DE603E3EA}"
    if (Confirm-RegValueIsDefined -RegPath $regKey -RegValueName "DllName")
    {
        $cseFile = Get-ItemPropertyValue -Path $regKey -Name "DllName"
        if (Test-Path -Path $cseFile) {
            $resultData.Installed = $true
        }
    }

    # Get LAPS configuration, if LAPS is enabled.
    $regKey = "HKLM:\Software\Policies\Microsoft Services\AdmPwd"
    if (Confirm-RegValueIsDefined -RegPath $regKey -RegValueName "AdmPwdEnabled")
    {
        # Is LAPS enabled?
        $regValue = Get-ItemPropertyValue -Path $regKey -Name "AdmPwdEnabled"
        if ($regValue -eq 1) {
            $resultData.Enabled = $true
        }

        # Get managed user (name) => Empty if default user or not configured.
        if (Confirm-RegValueIsDefined -RegPath $regKey -RegValueName "AdminAccountName")
        {
            $resultData.UserName = Get-ItemPropertyValue -Path $regKey -Name "AdminAccountName"
            if (-Not (Get-LocalUser -Name $resultData.UserName))
            {
                # If the managed user does not exist on the system, set the property to $false.
                $resultData.UserDoesExist = $false
            }
        }
    }

    # Return results
    return $resultData 
}


function Get-WindowsLapsState([bool]$IsLegacyCSE)
{
    # Function: Get-WindowsLapsState
    # The function checks if the Windows LAPS DLLs are available on this client and if Windows LAPS is configured.
    # Input parameter: [bool]$IsLegacyCSE : True if installed and false if not.
    # Returns an object with the following members:
    #    - Installed : Yes=$true, No=$false (bool value)
    #    - Enabled : Yes=$true, No=$false (bool value)
    #    - LegacyEmulation : Yes=$true, No=$false (bool value)
    #    - ConfigSource (Possible values: "CSP", "GPO", "Local configuration", "Legacy LAPS")
    #    - TargetDirectory (Possible values: "Azure AD", "Active Directory")
    #    - UserName
    #    - UserExists : Yes=$true, No=$false, <Builtin Admin>=$true

    # Initialize return object variable
    $resultData = [PSCustomObject]@{
        Installed = $true
        Enabled = $false
        LegacyEmulation = $false
        ConfigSource = "None"
        TargetDirectory = "None"
        UserName = ""
        UserDoesExist=$true
    }

    # If a component of Windows LAPS is missing, set the "installed" property to $false
    # - See also: https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-concepts
    if (-Not (Test-Path -Path "$($env:windir)\System32\laps.dll" -ErrorAction SilentlyContinue))
    {
        # Core DLL
        WriteLogDebug "Windows LAPS Core DLL (laps.dll) is missing!"
        $resultData.Installed=$false
    }
    elseif (-Not (Test-Path -Path "$($env:windir)\System32\lapscsp.dll" -ErrorAction SilentlyContinue))
    {
        # Configuration service provider (CSP)
        WriteLogDebug "Windows LAPS CSP DLL (lapscsp.dll) is missing!"
        $resultData.Installed=$false
    }
    elseif (-Not (Get-Module -Name Laps -ListAvailable))
    {
        # PowerShell Module
        WriteLogDebug "Windows LAPS PowerShell Module (LAPS) is missing!"
        $resultData.Installed=$false
    }

    # Get the Windows LAPS configuration
    # - See also: https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-management-policy-settings
    # - See also: https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-scenarios-legacy
    # - See also: https://github.com/MicrosoftDocs/windowsserverdocs/issues/6961
    $regKeyCSP = "HKLM:\Software\Microsoft\Policies\LAPS"
    $regKeyPolicy = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\LAPS"
    $regKeyLocal = "HKLM:\Software\Microsoft\Windows\CurrentVersion\LAPS\Config"
    $regKeyLegacy = "HKLM:\Software\Policies\Microsoft Services\AdmPwd"
    if (Confirm-RegValueIsDefined -RegPath $regKeyCSP -RegValueName "BackupDirectory")
    {
        # Windows LAPS CSP
        [int]$bD = Get-ItemPropertyValue -Path $regKeyCSP -Name "BackupDirectory"
        If ($bD -ne 0)
        {
            $resultData.Enabled = $true
            $resultData.ConfigSource = "CSP"
            $resultData.TargetDirectory = If ($bD -eq 1) {"Azure AD"} Else {"Active Directory"}

            # Get user name => Empty if default user or not configured.
            if (Confirm-RegValueIsDefined -RegPath $regKeyCSP -RegValueName "AdministratorAccountName")
            {
                $resultData.UserName = Get-ItemPropertyValue -Path $regKeyCSP -Name "AdministratorAccountName"
                if (-Not (Get-LocalUser -Name $resultData.UserName))
                {
                    # If the managed user does not exist on the system, set the property to $false.
                    $resultData.UserDoesExist = $false
                }
            }
        }
    }
    elseif (Confirm-RegValueIsDefined -RegPath $regKeyPolicy -RegValueName "BackupDirectory")
    {
        # Windows LAPS Group Policy
        [int]$bD = Get-ItemPropertyValue -Path $regKeyPolicy -Name "BackupDirectory"
        If ($bD -ne 0)
        {
            $resultData.Enabled = $true
            $resultData.ConfigSource = "GPO"
            $resultData.TargetDirectory = If ($bD -eq 1) {"Azure AD"} Else {"Active Directory"}

            # Get user name => Empty if default user or not configured.
            if (Confirm-RegValueIsDefined -RegPath $regKeyPolicy -RegValueName "AdministratorAccountName")
            {
                $resultData.UserName = Get-ItemPropertyValue -Path $regKeyPolicy -Name "AdministratorAccountName"
                if (-Not (Get-LocalUser -Name $resultData.UserName))
                {
                    # If the managed user does not exist on the system, set the property to $false.
                    $resultData.UserDoesExist = $false
                }
            }
        }
    }
    elseif (Confirm-RegValueIsDefined -RegPath $regKeyLocal -RegValueName "BackupDirectory")
    {
        # Windows LAPS Local configuration
        [int]$bD = Get-ItemPropertyValue -Path $regKeyLocal -Name "BackupDirectory"
        If ($bD -ne 0)
        {
            $resultData.Enabled = $true
            $resultData.ConfigSource = "Local configuration"
            $resultData.TargetDirectory = If ($bD -eq 1) {"Azure AD"} Else {"Active Directory"}

            # Get user name => Empty if default user or not configured.
            if (Confirm-RegValueIsDefined -RegPath $regKeyLocal -RegValueName "AdministratorAccountName")
            {
                $resultData.UserName = Get-ItemPropertyValue -Path $regKeyLocal -Name "AdministratorAccountName"
                if (-Not (Get-LocalUser -Name $resultData.UserName))
                {
                    # If the managed user does not exist on the system, set the property to $false.
                    $resultData.UserDoesExist = $false
                }
            }
        }
    }
    elseif ((Confirm-RegValueIsDefined -RegPath $regKeyLegacy -RegValueName "AdmPwdEnabled") -AND ($IsLegacyCSE -eq $false))
    {
        # Legacy Microsoft LAPS Policy (AdmPwd-Policy) - Legacy Emulation Mode. (Only if Legacy CSE is not installed.)
        If ((Get-ItemPropertyValue -Path $regKeyLegacy -Name "AdmPwdEnabled") -eq 1)
        {
            $resultData.Enabled = $true
            $resultData.ConfigSource = "Legacy LAPS"
            $resultData.TargetDirectory = "Active Directory"
            $resultData.LegacyEmulation = $true

            # Get user name => Empty if default user or not configured.
            if (Confirm-RegValueIsDefined -RegPath $regKeyLegacy -RegValueName "AdminAccountName")
            {
                $resultData.UserName = Get-ItemPropertyValue -Path $regKeyLegacy -Name "AdminAccountName"
                if (-Not (Get-LocalUser -Name $resultData.UserName))
                {
                    # If the managed user does not exist on the system, set the property to $false.
                    $resultData.UserDoesExist = $false
                }
            }
        }
    }

    # Return results
    return $resultData 
}


function Get-LapsResetTasks([bool]$LapsIsMandatory)
{
    # Function: Get-LapsResetTasks
    # Function to detect the LAPS configuration on the client and define the reset tasks
    # Input parameter:
    #    - [bool]$LapsIsMandatory : "$true" if yes and "$false" if not. (If set to "$true" the script aborts with an error, when there is no LAPS configuration.)
    # Returns: An object with the information which LAPS mode/version should be triggered for reset and if the corresponding user exists.
    # On error: If problems are detected the script aborts.

    # Initialize return object variable
    $resetOperations = [PSCustomObject]@{
        LegacyLaps = $false
        LegacyLapsUserExists = $false
        WinLaps = $false
        WinLapsInEmulationMode = $false
        WinLapsIsAzureTarget = $false
        WinLapsUserExists = $false
    }

    # Get configuration
    WriteLogDebug "Detecting LAPS configuration ..."
    $legacyLapsProperties = Get-LegacyLapsState;
    $winLapsProperties = Get-WindowsLapsState -IsLegacyCSE $legacyLapsProperties.Installed;
    WriteLogInfo "Legacy Microsoft LAPS: Installed = $(ConvertTo-YesNo $legacyLapsProperties.Installed), Enabled = $(ConvertTo-YesNo $legacyLapsProperties.Enabled)"
    WriteLogDebug "Legacy Microsoft LAPS user: $($legacyLapsProperties.UserName)"
    WriteLogInfo "Windows LAPS: Installed = $(ConvertTo-YesNo $winLapsProperties.Installed), Enabled = $(ConvertTo-YesNo $winLapsProperties.Enabled), Configuration source = $($winLapsProperties.ConfigSource), Target Directory = $($winLapsProperties.TargetDirectory), Legacy emulation mode = $(ConvertTo-YesNo $winLapsProperties.LegacyEmulation)"
    WriteLogDebug "Windows LAPS user: $($winLapsProperties.UserName)"

    # Checking results
    if (($legacyLapsProperties.Enabled -eq $false) -AND ($winLapsProperties.Enabled -eq $false))
    {
        # If LAPS is not enabled on this client exit/abort.
        if ($LapsIsMandatory) {
            ExitWithCodeMessage -errorCode 505 -errorMessage "ERROR: LAPS is not enabled for this client, but is mandatory!!"
        }
        else {
            ExitWithCodeMessage -errorCode 0 -errorMessage "LAPS is not enabled for this client. - Nothing to do."
        }
    }
    if ($legacyLapsProperties.Enabled -and $legacyLapsProperties.Installed -and $winLapsProperties.Enabled -and $winLapsProperties.Installed)
    {
        # "Windows LAPS" and legacy "Microsoft LAPS" can run side by side, as long as they manage different accounts.
        # - See also: https://github.com/MicrosoftDocs/windowsserverdocs/issues/6961#issuecomment-1382908222
        if ($legacyLapsProperties.UserName -eq $winLapsProperties.UserName)
        {
            ExitWithCodeMessage -errorCode 506 -errorMessage "ERROR: Legacy Microsoft LAPS and Windows LAPS are both installed, enabled and manage the same user account. - THIS WILL CAUSE PROBLEMS!!"
        }
    }
    if (($legacyLapsProperties.Enabled -eq $true) -and ($legacyLapsProperties.Installed -eq $false) -and ($winLapsProperties.LegacyEmulation -eq $false))
    {
        # The script throws an error if only legacy Microsoft LAPS is enabled and the legacy CSE is missing.
        # The script throws an error if legacy Microsoft LAPS and Windows LAPS are both enabled and the legacy CSE is missing. (They can run side by side.)
        # The script doesn't throw an error on missing legacy CSE, if "Windows LAPS" is running in Legacy Emulation Mode, because they use the same configuration source.
        ExitWithCodeMessage -errorCode 507 -errorMessage "ERROR: Legacy Microsoft LAPS is enabled, but not installed on this client!"
    }
    if (($winLapsProperties.Enabled -eq $true) -and ($winLapsProperties.Installed -eq $false))
    {
        # Windows LAPS must be available to use it.
        ExitWithCodeMessage -errorCode 508 -errorMessage "ERROR: Windows LAPS is enabled, but not available/supported on this client."
    }

    # Return result
    # - "Windows LAPS" and "legacy Microsoft LAPS" can run side by side, as long as they manage different accounts. (The check for different accounts happens a few lines before.)
    # - "Windows LAPS" can run in "Legacy Emulation Mode" if the legacy "Microsoft LAPS" CSE is not installed.
    # - The LAPS user account can only exist, if the corresponding LAPS is enabled/configured.
    $resetOperations.LegacyLaps = ($legacyLapsProperties.Enabled -and $legacyLapsProperties.Installed)
    $resetOperations.WinLaps = ($winLapsProperties.Enabled -and $winLapsProperties.Installed -and !$winLapsProperties.LegacyEmulation)
    $resetOperations.WinLapsInEmulationMode = ($winLapsProperties.Enabled -and $winLapsProperties.Installed -and $winLapsProperties.LegacyEmulation)
    $resetOperations.LegacyLapsUserExists = ($legacyLapsProperties.UserDoesExist -and $legacyLapsProperties.IsEnabled)
    $resetOperations.WinLapsUserExists = ($winLapsProperties.UserDoesExist -and $winLapsProperties.IsEnabled)
    $resetOperations.WinLapsIsAzureTarget = ($winLapsProperties.TargetDirectory -eq "Azure AD")
    return $resetOperations;
}


function Invoke-LapsResetCommands([PSCustomObject]$LapsResetTasks, [bool]$DoResetImmediately)
{
    # Function: Invoke-LapsResetCommands
    # The function invokes the commands to reset the LAPS passwords.
    # Input parameter:
    #    - [PSCustomObject]$LapsResetTasks : Custom object generated by the function "Get-LapsResetTasks" containing the required reset information.
    #    - [bool]$DoResetImmediately : $true = Reset immediately.; $false = Only set expiration time.

    # Debug/Log information
    WriteLogDebug "Starting reset sequence ..."
    WriteLogDebug "Final reset task summary: $($LapsResetTasks -replace ';',',' -replace '@{','' -replace '}',',') DoResetImmediately=$($DoResetImmediately)"
    if ($DoResetImmediately) { WriteLogInfo "Immediate reset is enabled." } Else { WriteLogInfo "Immediate reset is disabled. - Only expiration time will be set." }
    WriteLogInfo "Executing user account: $env:Username"

    # Reset Windows LAPS password.
    if ($LapsResetTasks.WinLaps)
    {
        WriteLogInfo "Resetting password for Windows LAPS user ..."

        try
        {
            if ($LapsResetTasks.WinLapsIsAzureTarget -or $DoResetImmediately)
            {
                # According to https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-scenarios-azure-active-directory#rotate-the-password expiration time change is not supported for Azure AD.
                if (-Not $DoResetImmediately)
                {
                    WriteLogInfo "WARNING: Setting expiration time is not supported for Azure AD environments! - Switching to immediate reset."
                }

                # Checking user account ...
                if ($LapsResetTasks.WinLapsUserExists -eq $false)
                {
                    ExitWithCodeMessage -errorCode 510 -errorMessage "ERROR: Failed to reset password for Windows LAPS user! - The user does not exist."
                }

                # We don't need special credentials here because the system account is allowed to reset the password.
                Reset-LapsPassword
            }
            Else
            {
                # We don't need special credentials here because the system account is allowed to reset the password.
                Set-LapsADPasswordExpirationTime -ComputerName $env:computername
            }

            WriteLogInfo "Password reset for Windows LAPS user: Successfully done."
        }
        catch
        {
            ExitWithCodeMessage -errorCode 511 -errorMessage "ERROR: Failed to reset password for Windows LAPS user! - $($_)"
        }
    }

    # The Legacy LAPS password can be reset, if Windows LAPS runs in Legacy Emulation Mode or if legacy Microsoft LAPS is available.
    if ($LapsResetTasks.WinLapsInEmulationMode -or $LapsResetTasks.LegacyLaps)
    {
        WriteLogInfo "Resetting password for legacy Microsoft LAPS user ..."
        if ($LapsResetTasks.WinLapsInEmulationMode) { WriteLogInfo "Windows LAPS is running in legacy Microsoft LAPS emulation mode. - Using the Microsoft LAPS module." }

        try
        {
            # We don't need special credentials here because the system account is allowed to reset the password.
            Reset-AdmPwdPassword -ComputerName $env:computername

            if ($DoResetImmediately -and $LapsResetTasks.LegacyLapsUserExists)
            {
                # We don't need special credentials here because the system account is allowed to reset the password.
                & gpupdate.exe /target:computer /force
            }
            elseif ($DoResetImmediately -and $LapsResetTasks.LegacyLapsUserExists -eq $false)
            {
                WriteLogInfo "WARNING: Legacy Microsoft LAPS user does not exist! - Only expiration time was set!"
            }

            WriteLogInfo "Password reset for legacy Microsoft LAPS user: Successfully done."
        }
        catch
        {
            ExitWithCodeMessage -errorCode 512 -errorMessage "ERROR: Failed to reset password for Microsoft LAPS user! - $($_)"
        }
    }

    # Sending log info
    WriteLogDebug "DEBUG: Reset sequence finished."
}



function Main() {
    WriteLogDebug "Starting ResetLapsPassword package.";

    # Check if running on Windows
    If (IsWinPeEnvironment) {
        $message = "ERROR: ResetLapsPassword package is running under WinPE. The execution is stopped."
        ExitWithCodeMessage -errorCode 501 -errorMessage $message;
    }

    # OS version check
    if ([System.Environment]::OSVersion.Version.Build -lt 19041) {
        $message = "ERROR: Windows 10 (Build 19041 or higher) or Windows 11 is required! The execution is stopped."
        ExitWithCodeMessage -errorCode 502 -errorMessage $message;
    }
    else {
        [string] $osInfo = (Get-WmiObject -class Win32_OperatingSystem).Caption + " " + (Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name "DisplayVersion") + " (Build $([System.Environment]::OSVersion.Version.Build))"
        WriteLogInfo -Message "Operating System: $($osInfo)"
    }

    # Check user context
    if (-Not [System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem) {
        ExitWithCodeMessage -errorCode 503 -errorMessage "ERROR: Script must run as 'Local System'!"
    }

    # Read package variables
    [int]$varIntuneSyncTimeout = ReadEmpirumVariable -varName ResetLapsPassword.IntuneSyncTimeout -defaultValue 10
    [bool]$varLapsIsMandatory = ReadEmpirumVariable -varName ResetLapsPassword.LapsIsMandatory -isBoolean -defaultValue 0
    [bool]$varLapsResetImmediately = ReadEmpirumVariable -varName ResetLapsPassword.ResetImmediately -isBoolean -defaultValue 0

    # Update device configuration and check if device is joined to an AD
    $isDeviceADJoined = Update-ClientMgmtConfiguration -IntuneSyncTimeout $varIntuneSyncTimeout
    If (($isDeviceADJoined -eq $false) -and ($varLapsIsMandatory -eq $false))
    {
        # LAPS only works on AD (Azure or local) joined systems, so we skip execution here.
        # We don't skip if LAPS is mandatory to fail later in the script.
        $message = "Device is not joined to Azure AD or a locale AD. - Further execution is skipped."
        ExitWithCodeMessage -errorCode 0 -errorMessage $message;
    }

    # Detect reset tasks
    $lapsResetTasks = Get-LapsResetTasks -LapsIsMandatory $varLapsIsMandatory

    # Import module for legacy Microsoft LAPS
    if ($lapsResetTasks.LegacyLaps -or $lapsResetTasks.WinLapsInEmulationMode)
    {
         try {
            [string] $lapsLegacyModulePath = (Split-Path $PSScriptRoot -Parent) + "\AdmPwd.PSModule\AdmPwd.PS.psd1"
            WriteLogInfo -message "Importing module for legacy 'Microsoft LAPS' (AdmPwd.PS.psd1) ..."
            WriteLogDebug "Module path: $($lapsLegacyModulePath)"
            Import-Module "$lapsLegacyModulePath" -ErrorAction Stop
            WriteLogInfo -message "Module imported successfully."
        } catch {
            ExitWithCodeMessage -errorCode 509 -errorMessage "ERROR: Failed to import PowerShell module for legacy Microsoft LAPS (AdmPwd.PS.psd1)! - $($_.Exception.Message)"
        }
    }

    # Invoke LAPS reset tasks
    Invoke-LapsResetCommands -LapsResetTasks $lapsResetTasks -DoResetImmediately $varLapsResetImmediately

    WriteLogDebug "Finished ResetLapsPassword package.";
}




###### Entry point of the Powershell script
############################################################################
Main;