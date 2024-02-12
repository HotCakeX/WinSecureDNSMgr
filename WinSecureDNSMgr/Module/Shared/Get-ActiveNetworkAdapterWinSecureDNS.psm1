function Get-ActiveNetworkAdapterWinSecureDNS {
    [CmdletBinding()]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    param()
    <#
    .SYNOPSIS
        Get the active physical network adapter that is providing Internet access and is not VPN virtual adapter
    .NOTES
        luckily, it's not normally possible to change description of network interfaces/adapters
        so it is a solid criteria for choosing our network adapter/interface
        https://serverfault.com/questions/862065/changing-nic-interface-descriptions-in-windows#:~:text=You%20can%27t%20change%20the%20name%20of%20the%20NICs,you%27ll%20have%20to%20do%20lots%20of%20name%20swapping
    .INPUTS
        None
    .OUTPUTS
        Microsoft.Management.Infrastructure.CimInstance
    #>
    try {
        # get the currently active network interface/adapter that is being used for Internet access
        # This gets the top most active adapter based on route metric
        $ActiveNetworkInterface = Get-NetRoute -DestinationPrefix '0.0.0.0/0', '::/0' -ErrorAction SilentlyContinue |
        Sort-Object -Property { $_.InterfaceMetric + $_.RouteMetric } -Top 1 -PipelineVariable ActiveAdapter |
        Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object -FilterScript { $_.ifIndex -eq $ActiveAdapter.ifIndex }

        # check if the top most active adapter that we got has an interface index
        # Windows built-in VPN client connections don't have interface index and don't appear in Get-NetAdapter results
        if (!$ActiveNetworkInterface) {
            Write-Verbose -Message "This adapter doesn't even exist in get-NetAdapter results and doesn't have interface index, must be built-in Windows VPN client adapter"

            # then we get the 2nd adapter from the top
            $ActiveNetworkInterface = Get-NetRoute -DestinationPrefix '0.0.0.0/0', '::/0' -ErrorAction SilentlyContinue |
            Sort-Object -Property { $_.InterfaceMetric + $_.RouteMetric } -Top 2 |
            Select-Object -Skip 1 | Select-Object -First 1 -PipelineVariable ActiveAdapter |
            Get-NetAdapter | Where-Object -FilterScript { $_.ifIndex -eq $ActiveAdapter.ifIndex }
        }
        # if the top most adapter that we got has an interface index
        else {

            # check if the detected active interface from the previous step is virtual, if it is, checks if it's an external virtual Hyper-V network adapter or VPN virtual network adapter
            if ((Get-NetAdapter | Where-Object { $_.InterfaceGuid -eq $ActiveNetworkInterface.InterfaceGuid }).Virtual) {
                Write-Verbose -Message "Interface is virtual, trying to find out if it's a VPN virtual adapter or Hyper-V External virtual switch"

                # if it's an external virtual Hyper-V network adapter, it must be the correct adapter
                if ($ActiveNetworkInterface.InterfaceDescription -like '*Hyper-V Virtual Ethernet Adapter*'  ) {
                    Write-Verbose -Message "The detected active network adapter is virtual, it's Hyper-V External switch"
                    $ActiveNetworkInterface = $ActiveNetworkInterface
                }

                # if the detected active network adapter is virtual but Not virtual external Hyper-V network adapter, which means it is VPN virtual network adapter (but not Windows built-in VPN client),
                # choose the second prioritized adapter/interface based on route metric
                # tested with Cloudflare WARP, Wintun, TAP, OpenVPN and has been always successful in detecting the correct network adapter/interface
                else {
                    Write-Verbose -Message 'Detected active network adapter is virtual but not virtual Hyper-V adapter, most likely a VPN virtual network adapter, choosing the second prioritized adapter/interface based on route metric'

                    $ActiveNetworkInterface = Get-NetRoute -DestinationPrefix '0.0.0.0/0', '::/0' -ErrorAction SilentlyContinue |
                    Sort-Object -Property { $_.InterfaceMetric + $_.RouteMetric } -Top 2 |
                    Select-Object -Skip 1 | Select-Object -First 1 -PipelineVariable ActiveAdapter |
                    Get-NetAdapter | Where-Object -FilterScript { $_.ifIndex -eq $ActiveAdapter.ifIndex }
                }
            }
        }
        Write-Verbose -Message 'This is the automatically detected network adapter the module is going to set Secure DNS for'
        return [Microsoft.Management.Infrastructure.CimInstance]$ActiveNetworkInterface
    }
    catch {
        Throw $_
    }
}
Export-ModuleMember -Function 'Get-ActiveNetworkAdapterWinSecureDNS'
