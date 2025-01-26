##############################################################################
# 1) Hide the PowerShell Window
##############################################################################

Add-Type -Name Win32 -Namespace Native -MemberDefinition @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

# Grab the current process’s window handle and hide it (0 = SW_HIDE).
$hWnd = (Get-Process -Id $PID).MainWindowHandle
[Native.Win32]::ShowWindow($hWnd, 0)

##############################################################################
# 2) A function to wait for mouse movement before proceeding
##############################################################################

function Wait-ForMouseMovement {
    Add-Type -AssemblyName System.Windows.Forms
    $originalPos = [System.Windows.Forms.Cursor]::Position

    Write-Host "Waiting for mouse movement..."
    while ($true) {
        Start-Sleep -Seconds 1
        $currentPos = [System.Windows.Forms.Cursor]::Position
        if (($currentPos.X -ne $originalPos.X) -or ($currentPos.Y -ne $originalPos.Y)) {
            break
        }
    }
    Write-Host "Mouse movement detected!"
}

##############################################################################
# 3) Define the PRANK script (Fake BSOD + Hide Icons + Hide Taskbar, etc.)
##############################################################################
function Start-Prank {
    # -- 3A) Provide .NET Interop for SystemParametersInfo (set wallpaper)
    $code = @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
}
"@
    Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue

    # -- 3B) Kill Wallpaper Engine Processes
    $processNames = @(
        "wallpaper64",
        "wallpaper32",
        "webwallpaper64",
        "webwallpaper32",
        "wallpaperservice32"
    )
    foreach ($processName in $processNames) {
        Stop-Process -Name $processName -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2

    # -- 3C) Hide Desktop Icons
    $Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $Path -Name "HideIcons" -Value 1

    $Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    If (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name "NoDesktop" -Value 1

    # -- 3D) Download BSOD Image & Set as Wallpaper
    $imageUrl = "https://1.bp.blogspot.com/-fifVJfHz0-M/XDjD30_jWcI/AAAAAAAAAWM/HQ3Uv5ZHVCo37RbllK7v927DMYUl36TJgCLcBGAs/s1600/blue%2Bscreen%2Bof%2Bdeath%2Bwindow%2B10.png"
    $imagePath = "$env:USERPROFILE\Downloads\bsod.png"
    (New-Object System.Net.WebClient).DownloadFile($imageUrl, $imagePath)

    [Win32]::SystemParametersInfo(0x0014, 0, $imagePath, 0x01 -bor 0x02) 
    # 0x0014 = SPI_SETDESKWALLPAPER
    # 0x1 | 0x2 = Update registry + send to all windows

    # -- 3E) Hide Taskbar
    $RegPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    $RegKey = (Get-ItemProperty -Path $RegPath).Settings
    $RegKey[8] = 3  # 3 = hide
    Set-ItemProperty -Path $RegPath -Name Settings -Value $RegKey

    # -- 3F) Restart Explorer to Apply Changes
    Stop-Process -Name explorer -Force
    Start-Process explorer

    # -- 3G) Final kill of the processes if they relaunch after a few seconds
    Start-Sleep -Seconds 6
    foreach ($processName in $processNames) {
        Stop-Process -Name $processName -Force -ErrorAction SilentlyContinue
    }

    # -- 3H) Minimize all windows
    $shell = New-Object -ComObject "Shell.Application"
    $shell.MinimizeAll()

    Write-Host "Prank (fake BSOD) is now active."
}

##############################################################################
# 4) Define the RESTORE script
##############################################################################
function Stop-Prank {
    # Provide .NET Interop for SystemParametersInfo again (if needed)
    $code = @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
    Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue

    # -- 4A) Restore Desktop Icons
    $Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $Path -Name "HideIcons" -Value 0

    $Path2 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    # In case we used NoDesktop=1, revert it:
    if (Test-Path $Path2) {
        Set-ItemProperty -Path $Path2 -Name "NoDesktop" -Value 0 -ErrorAction SilentlyContinue
    }

    # -- 4B) Download a "normal" wallpaper
    $imageUrl = "https://wallpapercave.com/wp/wp10128604.jpg"
    $imagePath = "$env:USERPROFILE\Downloads\normal.jpg"
    (New-Object System.Net.WebClient).DownloadFile($imageUrl, $imagePath)

    # -- 4C) Set it as wallpaper
    [Win32]::SystemParametersInfo(0x0014, 0, $imagePath, 0x01 -bor 0x02)

    # -- 4D) Show Taskbar
    $RegPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    $RegKey = (Get-ItemProperty -Path $RegPath).Settings
    $RegKey[8] = 2  # 2 = show
    Set-ItemProperty -Path $RegPath -Name Settings -Value $RegKey

    # -- 4E) Restart Explorer to apply
    Stop-Process -Name explorer -Force
    Start-Process explorer

    Write-Host "System restored to normal wallpaper and taskbar visible."
}

##############################################################################
# 5) PUT IT ALL TOGETHER
##############################################################################
# 5A) Run the prank first
Start-Prank

# 5B) Wait for mouse movement
Wait-ForMouseMovement

# 5C) Once mouse moves, restore
Stop-Prank

Write-Host "Done!"
