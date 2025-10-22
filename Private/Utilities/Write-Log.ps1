function Write-Log {
    <#
    .SYNOPSIS
        Writes log messages to file and console with color coding
    
    .DESCRIPTION
        Centralized logging function that writes messages to both file and console.
        Supports multiple log levels with corresponding color coding.
        This function replaces the 'Logging' function from the original script.
    
    .PARAMETER Message
        The message to log
    
    .PARAMETER Level
        The log level for the message
    
    .PARAMETER NoNewLine
        If specified, does not add a newline after the message
    
    .EXAMPLE
        Write-Log -Message "Starting operation" -Level INFO
    
    .EXAMPLE
        Write-Log -Message "Operation completed successfully" -Level SUCCESS
    
    .NOTES
        Log file path is stored in $Script:LogFilePath module variable
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('INFO', 'SUCCESS', 'ERROR', 'WARNING', 'MAINHEADER', 'HEADER', 'REMARK', 
                     'REMARK-IMPORTANT', 'REMARK-MORE-IMPORTANT', 'REMARK-MOST-IMPORTANT', 
                     'ACTION', 'ACTION-NO-NEW-LINE')]
        [string]$Level = 'INFO',
        
        [Parameter()]
        [switch]$NoNewLine
    )
    
    # Format timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] : $Message"
    
    # Write to log file if path is set
    if ($Script:LogFilePath) {
        try {
            Add-Content -Path $Script:LogFilePath -Value $logMessage -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to write to log file: $_"
        }
    }
    
    # Color mapping for console output
    $colorMap = @{
        'INFO' = 'Yellow'
        'SUCCESS' = 'Green'
        'ERROR' = 'Red'
        'WARNING' = 'Red'
        'MAINHEADER' = 'Magenta'
        'HEADER' = 'DarkCyan'
        'REMARK' = 'Cyan'
        'REMARK-IMPORTANT' = 'Green'
        'REMARK-MORE-IMPORTANT' = 'Yellow'
        'REMARK-MOST-IMPORTANT' = 'Red'
        'ACTION' = 'White'
        'ACTION-NO-NEW-LINE' = 'White'
    }
    
    # Prepare Write-Host parameters
    $writeParams = @{
        Object = $logMessage
        ForegroundColor = $colorMap[$Level]
    }
    
    # Add NoNewline parameter if specified or if level requires it
    if ($NoNewLine -or $Level -eq 'ACTION-NO-NEW-LINE') {
        $writeParams['NoNewline'] = $true
    }
    
    # Write to console
    Write-Host @writeParams
}
