# ============================
# SetCustomCursors.ps1
# ============================

$registryPath = "HKCU:\Control Panel\Cursors"
$originalCursors = @{
    "Arrow"      = (Get-ItemProperty -Path $registryPath -Name Arrow).Arrow
    "Help"       = (Get-ItemProperty -Path $registryPath -Name Help).Help
    "AppStarting"= (Get-ItemProperty -Path $registryPath -Name AppStarting).AppStarting
    "Wait"       = (Get-ItemProperty -Path $registryPath -Name Wait).Wait
    "Crosshair"  = (Get-ItemProperty -Path $registryPath -Name Crosshair).Crosshair
    "TextSelect" = (Get-ItemProperty -Path $registryPath -Name TextSelect).TextSelect
    "Hand"       = (Get-ItemProperty -Path $registryPath -Name Hand).Hand
}


$customCursorDir = "$env:TEMP\CustomCursors"
if (!(Test-Path $customCursorDir)) {
    New-Item -ItemType Directory -Path $customCursorDir | Out-Null
}

$githubBaseUrl = "https://github.com/FraDev-x/chroma"

# Map registry keys to the expected cursor filenames.
# Ensure these filenames match what you uploaded.
$customCursors = @{
    "Arrow"      = "Arrow.cur"
    "Help"       = "Help.cur"
    "AppStarting"= "AppStarting.cur"
    "Wait"       = "Wait.cur"
    "Crosshair"  = "Crosshair.cur"
    "TextSelect" = "TextSelect.cur"
    "Hand"       = "Hand.cur"
}

Write-Host "Downloading custom cursors... (OFFERED BY FP)"
foreach ($key in $customCursors.Keys) {
    $url = "$githubBaseUrl/$($customCursors[$key])"
    $destination = Join-Path $customCursorDir $customCursors[$key]
    Write-Host "  Downloading $url..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction Stop
    }
    catch {
        Write-Host "    [Error] Failed to download $url"
    }
}

# 3. Update the registry to use the downloaded custom cursors
Write-Host "Updating registry to apply custom cursors...(OFFERED BY FP)"
foreach ($key in $customCursors.Keys) {
    $cursorPath = Join-Path $customCursorDir $customCursors[$key]
    Set-ItemProperty -Path $registryPath -Name $key -Value $cursorPath
}

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
[NativeMethods]::SendMessageTimeout([NativeMethods]::HWND_BROADCAST, [NativeMethods]::WM_SETTINGCHANGE, [IntPtr]::Zero, "Control Panel", 0, 100, [ref]$result)

Write-Host "Custom cursors applied successfully. (OFFERED BY FP)"

function Restore-Cursors {
    Write-Host "Restoring original cursors..."
    foreach ($key in $originalCursors.Keys) {
        Set-ItemProperty -Path $registryPath -Name $key -Value $originalCursors[$key]
    }
    # Broadcast the change again to update the cursors
    [NativeMethods]::SendMessageTimeout([NativeMethods]::HWND_BROADCAST, [NativeMethods]::WM_SETTINGCHANGE, [IntPtr]::Zero, "Control Panel", 0, 100, [ref]$result)
    Write-Host "Original cursors restored."
}


Register-EngineEvent -SourceIdentifier Console.CancelKeyPress -Action { Restore-Cursors } | Out-Null

Add-Type -AssemblyName System.Windows.Forms
[Microsoft.Win32.SystemEvents]::SessionEnding += { Restore-Cursors }

Write-Host "The script will now keep running. When you shut down (or press Ctrl+C), the original cursors will be restored. (OFFERED BY FP)"
Write-Host "Press Ctrl+C if you wish to terminate the script manually. (OFFERED BY FP)"

while ($true) {
    Start-Sleep -Seconds 10
}
