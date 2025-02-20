$registryPath = "HKCU:\Control Panel\Cursors"
Write-Host "Reading original cursor paths..."
$originalCursors = @{
    "Arrow"      = (Get-ItemProperty -Path $registryPath -Name Arrow).Arrow
    "Help"       = (Get-ItemProperty -Path $registryPath -Name Help).Help
    "AppStarting"= (Get-ItemProperty -Path $registryPath -Name AppStarting).AppStarting
    "Wait"       = (Get-ItemProperty -Path $registryPath -Name Wait).Wait
    "Crosshair"  = (Get-ItemProperty -Path $registryPath -Name Crosshair).Crosshair
    "TextSelect" = (Get-ItemProperty -Path $registryPath -Name TextSelect).TextSelect
    "Hand"       = (Get-ItemProperty -Path $registryPath -Name Hand).Hand
}
Write-Host "Original cursor paths stored."

$customCursorDir = "$env:TEMP\CustomCursors"
Write-Host "Preparing temporary folder at $customCursorDir..."
if (!(Test-Path $customCursorDir)) {
    New-Item -ItemType Directory -Path $customCursorDir | Out-Null
}
Write-Host "Temporary folder is ready."

$githubBaseUrl = "https://raw.githubusercontent.com/FraDev-x/cursorreplace/main"
Write-Host "GitHub base URL set to: $githubBaseUrl"

$customCursors = @{
    "Arrow"      = "Normal Select.ani"
    "Help"       = "Help Select.ani"
    "AppStarting"= "Working in Background.ani"
    "Wait"       = "Busy.ani"
    "Crosshair"  = "Precision Select.ani"
    "TextSelect" = "Text Select.ani"
    "Hand"       = "Link Select.ani"
}
Write-Host "Custom cursor filenames defined."

Write-Host "Starting download of custom cursors..."
foreach ($key in $customCursors.Keys) {
    $url = "$githubBaseUrl/$(($customCursors[$key]) -replace ' ', '%20')"
    $destination = Join-Path $customCursorDir $customCursors[$key]
    Write-Host "Downloading $url to $destination..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction Stop
        Write-Host "Downloaded $key cursor successfully."
    }
    catch {
        Write-Host "Error: Failed to download $url"
    }
}
Write-Host "Custom cursors downloaded."

Write-Host "Updating registry with custom cursor paths..."
foreach ($key in $customCursors.Keys) {
    $cursorPath = Join-Path $customCursorDir $customCursors[$key]
    Write-Host "Setting $key to $cursorPath..."
    Set-ItemProperty -Path $registryPath -Name $key -Value $cursorPath
    Set-ItemProperty -Path $registryPath -Name "Scheme Source" -Value 2
}
Write-Host "Registry updated with custom cursor paths."

Write-Host "Forcing system to update cursor settings..."
1..3 | ForEach-Object {
    Start-Process -FilePath "rundll32.exe" -ArgumentList "user32.dll,UpdatePerUserSystemParameters,1,True" -NoNewWindow -Wait
    Start-Sleep -Milliseconds 500
}
Write-Host "System parameters updated via rundll32."

Write-Host "Compiling native method for broadcasting settings change..."
$code = @"
using System;
using System.Runtime.InteropServices;
public class NativeMethods {
    public const int WM_SETTINGCHANGE = 0x1A;
    public static IntPtr HWND_BROADCAST = new IntPtr(0xffff);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(IntPtr hWnd, int Msg, IntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
}
"@
Add-Type $code

[IntPtr]$result = [IntPtr]::Zero
Write-Host "Broadcasting WM_SETTINGCHANGE message..."
[NativeMethods]::SendMessageTimeout([NativeMethods]::HWND_BROADCAST, [NativeMethods]::WM_SETTINGCHANGE, [IntPtr]::Zero, "Control Panel", 0, 100, [ref]$result)
Write-Host "WM_SETTINGCHANGE broadcast sent."
Write-Host "Custom cursors applied successfully."

Write-Host "Registering event for restoring original cursors on exit..."
function Restore-Cursors {
    Write-Host "Restoring original cursor settings..."
    foreach ($key in $originalCursors.Keys) {
        Write-Host "Restoring $key..."
        Set-ItemProperty -Path $registryPath -Name $key -Value $originalCursors[$key]
    }
    Set-ItemProperty -Path $registryPath -Name "Scheme Source" -Value 2
    1..3 | ForEach-Object {
        Start-Process -FilePath "rundll32.exe" -ArgumentList "user32.dll,UpdatePerUserSystemParameters,1,True" -NoNewWindow -Wait
        Start-Sleep -Milliseconds 500
    }
    [NativeMethods]::SendMessageTimeout([NativeMethods]::HWND_BROADCAST, [NativeMethods]::WM_SETTINGCHANGE, [IntPtr]::Zero, "Control Panel", 0, 100, [ref]$result)
    Write-Host "Original cursors restored."
}
Register-EngineEvent -SourceIdentifier Console.CancelKeyPress -Action { Restore-Cursors } | Out-Null

Add-Type -AssemblyName System.Windows.Forms

Write-Host "Script is now running. Press Ctrl+C to restore original cursors and exit."
while ($true) {
    Start-Sleep -Seconds 10
}
