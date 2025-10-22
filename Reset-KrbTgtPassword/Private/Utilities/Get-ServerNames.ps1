function Get-ServerNames {
    <#
    .SYNOPSIS
        Retrieves various server name formats for the local computer
    
    .DESCRIPTION
        Gets different name formats for the local server including NetBIOS name,
        AD domain FQDN, computer FQDN in AD domain, computer FQDN in DNS domain,
        and DNS domain FQDN.
        
        This function replaces the 'getServerNames' function from the original script.
        It supports disjoint namespace scenarios where AD domain FQDN differs from DNS FQDN.
    
    .OUTPUTS
        Returns array with:
        [0] NetBIOS computer name
        [1] FQDN of AD domain
        [2] FQDN of computer in AD domain
        [3] FQDN of computer in DNS domain
        [4] FQDN of DNS domain
    
    .EXAMPLE
        $names = Get-ServerNames
        $netbiosName = $names[0]
        $adDomain = $names[1]
    
    .NOTES
        Useful for determining server identity in various naming contexts
        Handles disjoint namespace scenarios
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    
    try {
        Write-Verbose "Retrieving server names"
        
        # Get computer system information
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        
        # NetBIOS computer name
        $netbiosName = $computerSystem.Name
        Write-Verbose "NetBIOS Name: $netbiosName"
        
        # AD domain FQDN
        $adDomainFqdn = $computerSystem.Domain
        Write-Verbose "AD Domain FQDN: $adDomainFqdn"
        
        # Computer FQDN in AD domain
        $computerInAdDomain = "$netbiosName.$adDomainFqdn"
        Write-Verbose "Computer in AD Domain: $computerInAdDomain"
        
        # Computer FQDN in DNS domain (may differ in disjoint namespace)
        $computerInDns = [System.Net.Dns]::GetHostByName($netbiosName).HostName
        Write-Verbose "Computer in DNS: $computerInDns"
        
        # DNS domain FQDN (extracted from computer DNS name)
        $dnsDomain = if ($computerInDns.Contains('.')) {
            $computerInDns.Substring($computerInDns.IndexOf('.') + 1)
        } else {
            $adDomainFqdn
        }
        Write-Verbose "DNS Domain: $dnsDomain"
        
        # Return array of server names
        return @(
            $netbiosName,
            $adDomainFqdn,
            $computerInAdDomain,
            $computerInDns,
            $dnsDomain
        )
    }
    catch {
        Write-Error "Failed to retrieve server names: $_"
        throw
    }
}
