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

$githubBaseUrl = "https://raw.githubusercontent.com/FraDev-x/cursorreplace/main"

$customCursors = @{
    "Arrow"      = "Normal Select.ani"
    "Help"       = "Help Select.ani"
    "AppStarting"= "Working in Background.ani"
    "Wait"       = "Busy.ani"
    "Crosshair"  = "Precision Select.ani"
    "TextSelect" = "Text Select.ani"
    "Hand"       = "Link Select.ani"
}

foreach ($key in $customCursors.Keys) {
    $url = "$githubBaseUrl/$(($customCursors[$key]) -replace ' ', '%20')"
    $destination = Join-Path $customCursorDir $customCursors[$key]
    try {
        Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction Stop
    }
    catch {
        Write-Host "Error: Failed to download $url"
    }
}

$cursorUpdaterCode = @"
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
Add-Type $cursorUpdaterCode

$registryUtilsCode = @'
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
Add-Type -TypeDefinition $registryUtilsCode

foreach ($key in $customCursors.Keys) {
    $cursorPath = Join-Path $customCursorDir $customCursors[$key]
    Set-ItemProperty -Path $registryPath -Name $key -Value $cursorPath
}
Set-ItemProperty -Path $registryPath -Name "Scheme Source" -Value 2

$HWND_BROADCAST = [IntPtr]::new(-1)
[RegistryUtils]::SendMessage($HWND_BROADCAST, [RegistryUtils]::WM_SETTINGCHANGE, [IntPtr]::Zero, [IntPtr]::Zero)

1..5 | ForEach-Object {
    [CursorUpdater]::SystemParametersInfo([CursorUpdater]::SPI_SETCURSORS, 0, [IntPtr]::Zero, [CursorUpdater]::SPIF_UPDATEINIFILE -bor [CursorUpdater]::SPIF_SENDCHANGE)
    Start-Sleep -Milliseconds 1000
}

function Restore-Cursors {
    foreach ($key in $originalCursors.Keys) {
        Set-ItemProperty -Path $registryPath -Name $key -Value $originalCursors[$key]
    }
    Set-ItemProperty -Path $registryPath -Name "Scheme Source" -Value 2
    
    [RegistryUtils]::SendMessage($HWND_BROADCAST, [RegistryUtils]::WM_SETTINGCHANGE, [IntPtr]::Zero, [IntPtr]::Zero)
    
    1..3 | ForEach-Object {
        [CursorUpdater]::SystemParametersInfo([CursorUpdater]::SPI_SETCURSORS, 0, [IntPtr]::Zero, [CursorUpdater]::SPIF_UPDATEINIFILE -bor [CursorUpdater]::SPIF_SENDCHANGE)
        Start-Sleep -Milliseconds 500
    }
}

Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Restore-Cursors } | Out-Null
$null = [Console]::CancelKeyPress.Register({ 
    Restore-Cursors
    [Environment]::Exit(0)
})

Add-Type -AssemblyName System.Windows.Forms

Write-Host "Press Ctrl+C to restore original cursors and exit."
try {
    while ($true) {
        Start-Sleep -Seconds 10
    }
} finally {
    Restore-Cursors
}
