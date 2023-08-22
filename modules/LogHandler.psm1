#########################################
#    LOG HANDLER CLASS                  #
#    AUTHOR: ELI KEIMIG @ DATAPRIVIA    #
#    LAST UPDATED: 20220728             #
#########################################

class LogHandler {
    [string]$LogFilePath
    [string]$LogFileName
    [string]$LogFileAbsolutePath
    [Boolean]$ConsoleOutput = $false

    LogHandler(
        [string]$LogFilePath,
        [string]$LogFileName,
        [Boolean]$ConsoleOutput = $false
    ) {
        $this.LogFilePath = $LogFilePath
        $this.LogFileName = $LogFileName
        $this.LogFileAbsolutePath = "$($this.LogFilePath)\$($this.LogFileName)"
        $this.ConsoleOutput = $ConsoleOutput
        if (Test-Path $this.LogFilePath) {
            Write-Host "Logging directory [$LogFilePath] exists: VERIFIED" -ForegroundColor Green
        }
        else
        {
            New-Item $this.LogFilePath -ItemType Directory
            Write-Host "Logging directory [$LogFilePath] created: VERIFIED" -ForegroundColor Green
        }
    }

    [void]Log(
        [string]$Message
    ) {
        $DateTimeStamp = Get-Date -Format "o"
        "$DateTimeStamp`t$Message" | out-file -Filepath "$($this.LogFileAbsolutePath)" -append

        if ($this.ConsoleOutput -eq $true) {
            Write-Host "$DateTimeStamp`t$Message"
        }
    }

    [void]Log(
        [string]$Message,
        [string]$Color = "White"
    ) {
        $DateTimeStamp = Get-Date -Format "o"
        "$DateTimeStamp`t$Message" | out-file -Filepath "$($this.LogFileAbsolutePath)" -append

        if ($this.ConsoleOutput -eq $true) {
            Write-Host "$DateTimeStamp`t$Message" -ForegroundColor $Color
        }
    }

    [void]ErrorLog(
        [string]$Message,
        $CaughtException
    ) {
        $DateTimeStamp = Get-Date -Format "o"
        "$DateTimeStamp`tERROR: $Message`t$CaughtException" | out-file -Filepath "$($this.LogFileAbsolutePath)" -append

        if ($this.ConsoleOutput -eq $true) {
            Write-Host "$DateTimeStamp`tERROR: $Message`t$CaughtException"
            Write-Host $CaughtException.ScriptStackTrace
        }
    }
}
