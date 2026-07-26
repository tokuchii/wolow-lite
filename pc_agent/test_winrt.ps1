Add-Type -AssemblyName System.Runtime.WindowsRuntime

[void][Windows.Media.Devices.MediaDevice, Windows.Media.Devices, ContentType = WindowsRuntime]
[void][Windows.Devices.Enumeration.DeviceInformation, Windows.Devices.Enumeration, ContentType = WindowsRuntime]

$selector = [Windows.Media.Devices.MediaDevice]::GetAudioRenderSelector()
$devices = [Windows.Devices.Enumeration.DeviceInformation]::FindAllAsync($selector).GetAwaiter().GetResult()

Write-Host "Found $($devices.Count) devices"
foreach ($d in $devices) {
    Write-Host "  $($d.Id) | $($d.Name) | enabled=$($d.IsEnabled)"
}
