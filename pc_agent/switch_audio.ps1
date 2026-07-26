$targetId = $args[0]

Add-Type @"
using System;
using System.Runtime.InteropServices;

[ComImport, Guid("CA286FC3-91FD-42C3-8E9B-CAAFA66242E3"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IPolicyConfig {
    [PreserveSig] int GetMixFormat(IntPtr pwstrId, out IntPtr ppFormat);
    [PreserveSig] int GetDeviceFormat(IntPtr pwstrId, bool bRaw, out IntPtr ppFormat);
    [PreserveSig] int SetDeviceFormat(IntPtr pwstrId, IntPtr pFormat);
    [PreserveSig] int GetProcessingPeriod(IntPtr pwstrId, bool bRaw, out long pDefaultPeriod, out long pMinPeriod, out long pMaxPeriod, out long pDefaultPreroll, out long pMinPreroll, out long pMaxPreroll);
    [PreserveSig] int SetProcessingPeriod(IntPtr pwstrId, long pDefaultPeriod);
    [PreserveSig] int SetSharedMode(IntPtr pwstrId, int a, int b);
    [PreserveSig] int SetDefaultEndpoint(IntPtr pwstrId, int role);
    [PreserveSig] int SetEndpointVisibility(IntPtr pwstrId, bool bVisible);
}
"@

try {
    $enumerator = New-Object -ComObject "MMDeviceEnumerator"
    $endpoints = $enumerator.EnumAudioEndpoints(0, 1)
    $count = $endpoints.Count
    $found = $false

    for ($i = 0; $i -lt $count; $i++) {
        $dev = $endpoints.Item($i)
        $devId = $dev.GetId()
        if ($devId -eq $targetId) {
            $iid = [Guid]"CA286FC3-91FD-42C3-8E9B-CAAFA66242E3"
            $hr = $dev.Activate([ref]$iid, 0x17, [IntPtr]::Zero, [ref]$policyConfig)
            if ($policyConfig) {
                $pc = [IPolicyConfig]$policyConfig
                $pc.SetDefaultEndpoint($targetId, 0)
                $pc.SetDefaultEndpoint($targetId, 1)
                $pc.SetDefaultEndpoint($targetId, 2)
                Write-Output '{"ok": true}'
                $found = $true
            } else {
                Write-Output '{"ok": false, "error": "Activate failed"}'
                $found = $true
            }
            break
        }
    }
    if (-not $found) {
        Write-Output '{"ok": false, "error": "device not found"}'
    }
} catch {
    Write-Output ('{"ok": false, "error": "' + $_.Exception.Message + '"}')
}
