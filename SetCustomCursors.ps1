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
}

Set-ItemProperty -Path $registryPath -Name "Scheme Source" -Value 2
Write-Host "Registry updated with custom cursor paths."
   
$code = @'
using System;
using System.Runtime.InteropServices;

public class RegistryUtils {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    
    [DllImport("user32.dll", SetLastError=true)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    
    public const int HWND_BROADCAST = 0xffff;
    public const int WM_SETTINGCHANGE = 0x001A;
}
'@
Add-Type -TypeDefinition $code

Write-Host "Broadcasting settings change..."
$HWND_BROADCAST = [IntPtr]::new(-1)
[RegistryUtils]::SendMessage($HWND_BROADCAST, [RegistryUtils]::WM_SETTINGCHANGE, [IntPtr]::Zero, [IntPtr]::Zero)

Write-Host "Applying cursor changes..."
1..5 | ForEach-Object {
    [CursorUpdater]::SystemParametersInfo([CursorUpdater]::SPI_SETCURSORS, 0, [IntPtr]::Zero, [CursorUpdater]::SPIF_UPDATEINIFILE -bor [CursorUpdater]::SPIF_SENDCHANGE)
    Start-Sleep -Milliseconds 1000
}

Write-Host "Compiling native method for broadcasting settings change..."
$code = @"
using System;
using System.Runtime.InteropServices;
public class CursorUpdater {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);
    public const uint SPI_SETCURSORS = 0x0057;
    public const uint SPIF_UPDATEINIFILE = 0x01;
    public const uint SPIF_SENDCHANGE = 0x02;
}
"@
Add-Type $code

Write-Host "Registering event for restoring original cursors on exit..."
function Restore-Cursors {
    Write-Host "Restoring original cursor settings..."
    foreach ($key in $originalCursors.Keys) {
        Write-Host "Restoring $key..."
        Set-ItemProperty -Path $registryPath -Name $key -Value $originalCursors[$key]
    }
    Set-ItemProperty -Path $registryPath -Name "Scheme Source" -Value 2
    1..3 | ForEach-Object {
        [CursorUpdater]::SystemParametersInfo([CursorUpdater]::SPI_SETCURSORS, 0, [IntPtr]::Zero, [CursorUpdater]::SPIF_UPDATEINIFILE -bor [CursorUpdater]::SPIF_SENDCHANGE)
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
