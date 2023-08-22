######################################################
#    ACTIVE DIRECTORY USER ATTRIBUTE PROVISIONING    #
#    AUTHOR: ELI KEIMIG @ DATAPRIVIA                 #
#    LAST UPDATED: 20220921                          #
######################################################

Using module C:\ActiveDirectoryProvisioning\modules\LogHandler.psm1

param (
    [Parameter(Mandatory)]$mode,
    [string]$importFile,
    [string]$username,
    [string]$userAttribute,
    [string]$attributeValue,
    [bool]$help
)

Write-Host "Beginning process setup..."

$scriptDirectory = Split-Path -Path "$($MyInvocation.MyCommand.Definition)"
Set-Location -path $scriptDirectory
function Show-Help {
    Write-Host "This script is used to provision user attributes in Active Directory."
    Write-Host "The script can be run in one of three modes (specified by the -mode flag):"
    Write-Host "    1. Batch mode [-mode batch]: This mode is used to import a CSV file containing a list of users and their attributes."
    Write-Host "       * The CSV file must have the following headers and be formatted as follows:"
    Write-Host "           * Column 1: Username"
    Write-Host "           * Column 2+ (optional): User attributes as found in the settings.json file in the 'conf' directory"
    Write-Host "       * The CSV file must be specified using the -importFile parameter and the -mode parameter must be set to 'batch'"
    Write-Host "    2. Single mode [-mode single]: This mode is used to provision a single user attribute."
    Write-Host "       * The username must be specified using the -username parameter"
    Write-Host "       * The user attribute must be specified using the -userAttribute parameter"
    Write-Host "       * The attribute value must be specified using the -attributeValue parameter"
    Write-Host "    3. Help mode [-mode help OR -help]: This mode is used to display this help message."
}

if ($help -or $mode -eq "help") {
    Show-Help
}

$validModes = @("batch", "single")

if ($validModes -notcontains $mode) {
    Write-Host "Invalid mode. Please specify either 'batch' or 'single'." -ForegroundColor Red
    Show-Help
    exit
}

if ($mode -eq "batch") {
    if ($null -eq $importFile) {
        Write-Host "No import file specified. Please specify an import file using -importFile." -ForegroundColor Red
        exit
    }
    elseif (Test-Path $importFile) {
        Write-Host "Import file [$importFile] exists: VERIFIED" -ForegroundColor Green
    }
    else
    {
        Write-Host "Import file [$importFile] does not exist. Please specify a valid import file." -ForegroundColor Red
        exit
    }
}
elseif ($mode -eq "single") {
    if ($null -eq $username -or $username -eq "") {
        Write-Host "No username specified. Please specify a username using -username." -ForegroundColor Red
        exit
    }
    elseif ($null -eq $userAttribute -or $userAttribute -eq "") {
        Write-Host "No user attribute specified. Please specify a user attribute using -userAttribute." -ForegroundColor Red
        exit
    }
    elseif ($null -eq $attributeValue -or $attributeValue -eq "") {
        Write-Host "No attribute value specified. Please specify an attribute value using -attributeValue." -ForegroundColor Red
        exit
    }
}
else {
    Write-Host "Invalid mode. Please specify either 'batch' or 'single'." -ForegroundColor Red
    exit
}


$Settings = Get-Content -Path .\conf\settings.json | ConvertFrom-Json -AsHashtable

[LogHandler]$LogHandler = [LogHandler]::new(
    $Settings.LogFilePath,  # Path to log file (required)
    $Settings.LogFileName,  # Name of log file (required)
    $true  # Write output to console as well ($false to hide output)
)

$BatchImportAttributes = $Settings.BatchImportAttributes
$AllowedActiveDirectoryAttributes = @()
foreach ($attribute in $BatchImportAttributes) {
    $AllowedActiveDirectoryAttributes += @($attribute.ActiveDirectoryAttribute)
}

Write-Host "Process setup complete. Starting..."

$LogHandler.Log('Importing Active Directory PowerShell module...')
try {
    Import-Module ActiveDirectory
}
catch {
    $LogHandler.ErrorLog('Failed to import Active Directory Module - it may not be installed.', $_)
}

if ($mode -eq "batch") {
    $LogHandler.Log("Beginning batch run using import file [$importFile]...")
    $importData = Import-Csv -Path $importFile
    foreach ($user in $importData) {
        $LogHandler.Log("Beginning processing for user [$($user.Username)]...")
        try {
            $validatedUser = Get-ADUser -Identity $user.Username
            $LogHandler.Log("User validated as [$($validatedUser.GivenName) $($validatedUser.Surname)]", "Green")
        }
        catch {
            $LogHandler.ErrorLog("Failed to validate user [$($user.Username)].", $_)
            continue
        }
        foreach ($attribute in $BatchImportAttributes) {
            try {
                if ($null -eq $( $user.($attribute.ImportFileField) ) -or $( $user.($attribute.ImportFileField) ) -eq "") {
                    $LogHandler.Log("No value specified for attribute [$($attribute.ActiveDirectoryAttribute)]. Skipping...")
                    continue
                }
                else {
                    Set-ADUser -Identity $user.Username -Replace @{ $attribute.ActiveDirectoryAttribute = $user.($attribute.ImportFileField) }
                    $LogHandler.Log("Attribute [$($attribute.ActiveDirectoryAttribute)] set to [$($user.($attribute.ImportFileField))] for user [$($user.Username)].", "Green")
                }
            }
            catch {
                $LogHandler.ErrorLog("Failed to set attribute [$($attribute.ActiveDirectoryAttribute)] to [$($user.($attribute.ImportFileField))] for user [$($user.Username)].", $_)
                continue
            }
        }
    }
}
elseif ($mode -eq "single") {
    $LogHandler.Log("Beginning single run for user [$username]...")
    try {
        $validatedUser = Get-ADUser -Identity $username
        $LogHandler.Log("User validated as [$($validatedUser.GivenName) $($validatedUser.Surname)]", "Green")
    }
    catch {
        $LogHandler.ErrorLog("Failed to validate user [$username].", $_)
        exit
    }
    try {
        if ($AllowedActiveDirectoryAttributes -notcontains $userAttribute) {
            $LogHandler.Log("Attribute [$($userAttribute)] is not allowed. Skipping...", "Red")
            exit
        }
        elseif ($null -eq $( $attributeValue ) -or $( $attributeValue ) -eq "") {
            $LogHandler.Log("No value specified for attribute [$($userAttribute)]. Skipping...", "Red")
            exit
        }
        else {
            $ConfirmAttributeSet = Read-Host "Are you sure you want to set attribute [$userAttribute] to [$attributeValue] for user [$username]? (y/N)"
            if ($ConfirmAttributeSet -eq "Y" -or $ConfirmAttributeSet -eq "y") {
                Set-ADUser -Identity $username -Replace @{ $userAttribute = $attributeValue }
                $LogHandler.Log("Attribute [$userAttribute] set to [$attributeValue] for user [$username].", "Green")
            }
            else {
                $LogHandler.Log("Attribute set cancelled.")
                exit
            }
        }
    }
    catch {
        $LogHandler.ErrorLog("Failed to set attribute [$userAttribute] to [$attributeValue] for user [$username].", $_)
        exit
    }
}
else {
    Write-Host "Invalid mode. Please specify either 'batch' or 'single'." -ForegroundColor Red
    exit
}

$LogHandler.Log('Process complete')
