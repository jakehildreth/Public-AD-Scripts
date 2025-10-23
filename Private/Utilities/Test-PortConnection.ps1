function Test-PortConnection {
    <#
    .SYNOPSIS
        Tests TCP port connectivity to a remote host
    
    .DESCRIPTION
        Tests whether a specific TCP port on a remote computer is accessible.
        Includes DNS resolution check before attempting port connection.
        This function replaces the 'portConnectionCheck' function from the original script.
    
    .PARAMETER ComputerName
        The FQDN or hostname to test
    
    .PARAMETER Port
        The TCP port number to test
    
    .PARAMETER TimeoutMs
        Timeout in milliseconds (default: 2000)
    
    .OUTPUTS
        Returns 'SUCCESS' if connection successful, 'ERROR' otherwise
    
    .EXAMPLE
        Test-PortConnection -ComputerName "dc01.contoso.com" -Port 389
    
    .EXAMPLE
        Test-PortConnection -ComputerName "dc01.contoso.com" -Port 389 -TimeoutMs 5000
    
    .NOTES
        Tests both DNS resolution and TCP connectivity
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,
        
        [Parameter(Mandatory = $true)]
        [int]$Port,
        
        [Parameter()]
        [int]$TimeoutMs = 2000
    )
    
    try {
        # First, test DNS resolution
        Write-Verbose "Testing DNS resolution for $ComputerName"
        $null = [System.Net.Dns]::GetHostEntry($ComputerName)
    }
    catch {
        Write-Verbose "DNS resolution failed for $ComputerName : $_"
        return 'ERROR'
    }
    
    # Test TCP port connectivity
    $tcpClient = $null
    try {
        Write-Verbose "Testing TCP connection to ${ComputerName}:${Port}"
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connectTask = $tcpClient.BeginConnect($ComputerName, $Port, $null, $null)
        $waitResult = $connectTask.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        
        if (-not $waitResult) {
            Write-Verbose "Connection to ${ComputerName}:${Port} timed out after ${TimeoutMs}ms"
            return 'ERROR'
        }
        
        try {
            $tcpClient.EndConnect($connectTask)
            Write-Verbose "Successfully connected to ${ComputerName}:${Port}"
            return 'SUCCESS'
        }
        catch {
            Write-Verbose "Failed to complete connection to ${ComputerName}:${Port} : $_"
            return 'ERROR'
        }
    }
    catch {
        Write-Verbose "Exception testing connection to ${ComputerName}:${Port} : $_"
        return 'ERROR'
    }
    finally {
        if ($tcpClient) {
            $tcpClient.Close()
            $tcpClient.Dispose()
        }
    }
}
