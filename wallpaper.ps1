# Requires .NET for pinvoke
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class WinAPI
{
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    // SW_MINIMIZE = 6
    public const int SW_MINIMIZE = 6;
}
"@

###############################################################################
# 1. CAPTURE CURRENT SETTINGS
###############################################################################
Write-Host "Capturing current user wallpaper and registry settings..."

# Current wallpaper (stored in HKCU:\Control Panel\Desktop)
$originalWallpaper = (Get-ItemProperty "HKCU:\Control Panel\Desktop").Wallpaper

# HideIcons
$hideIconsPath  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$originalHideIcons = (Get-ItemProperty -Path $hideIconsPath -Name "HideIcons" -ErrorAction SilentlyContinue).HideIcons

# NoDesktop
$policiesPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
if (!(Test-Path $policiesPath)) { 
    New-Item -Path $policiesPath | Out-Null 
}
$originalNoDesktop = (Get-ItemProperty -Path $policiesPath -Name "NoDesktop" -ErrorAction SilentlyContinue).NoDesktop

# Taskbar settings in StuckRects3
$stuckRectsPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
$originalStuckRects = (Get-ItemProperty -Path $stuckRectsPath -Name "Settings" -ErrorAction SilentlyContinue).Settings

Write-Host "Original Wallpaper:  $originalWallpaper"
Write-Host "Original HideIcons:  $originalHideIcons"
Write-Host "Original NoDesktop:  $originalNoDesktop"
Write-Host "Original StuckRects: $($originalStuckRects -join ',')"

###############################################################################
# 2. DEFINE PRANK FUNCTION
###############################################################################
function Invoke-Prank {
    Write-Host "`n--- PRANK: Hiding icons, setting fake BSOD... ---`n"

    # Optionally kill Wallpaper Engine processes
    $processNames = @("wallpaper64","wallpaper32","webwallpaper64","webwallpaper32","wallpaperservice32")
    foreach ($name in $processNames) {
        Stop-Process -Name $name -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep 1

    # Hide desktop icons
    Set-ItemProperty -Path $hideIconsPath -Name "HideIcons" -Value 1

    # Disable the desktop
    Set-ItemProperty -Path $policiesPath -Name "NoDesktop" -Value 1

    # Download a fake BSOD image
    $fakeBSODUrl = "https://1.bp.blogspot.com/-fifVJfHz0-M/XDjD30_jWcI/AAAAAAAAAWM/HQ3Uv5ZHVCo37RbllK7v927DMYUl36TJgCLcBGAs/s1600/blue%2Bscreen%2Bof%2Bdeath%2Bwindow%2B10.png"
    $bsodImagePath = "$env:USERPROFILE\Downloads\fake_bsod.png"
    try {
        (New-Object System.Net.WebClient).DownloadFile($fakeBSODUrl, $bsodImagePath)
    } catch {
        Write-Host "Error downloading BSOD image: $($_.Exception.Message)"
    }

    # Set wallpaper to the fake BSOD
    # SPI_SETDESKWALLPAPER = 0x14, SPIF_UPDATEINIFILE(0x1) + SPIF_SENDWININICHANGE(0x2)
    [WinAPI]::SystemParametersInfo(0x14, 0, $bsodImagePath, 0x1 -bor 0x2) | Out-Null

    # Hide the taskbar via StuckRects3
    # Typically byte index [8] = 3 => autohide/hide, 2 => normal
    if ($originalStuckRects) {
        $newStuckRects = New-Object byte[] ($originalStuckRects.Length)
        $originalStuckRects.CopyTo($newStuckRects, 0)
        $newStuckRects[8] = 3
        Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value $newStuckRects
    } else {
        # If not found, read the current, tweak it
        $regKey = (Get-ItemProperty -Path $stuckRectsPath).Settings
        $regKey[8] = 3
        Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value $regKey
    }

    # Restart Explorer to apply changes
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer
    Start-Sleep 1

    # Force-minimize all visible windows using EnumWindows + ShowWindow(SW_MINIMIZE)
    [WinAPI]::EnumWindows({
        param($hWnd, $lParam)

        if ([WinAPI]::IsWindowVisible($hWnd)) {
            # 6 = SW_MINIMIZE
            [WinAPI]::ShowWindow($hWnd, [WinAPI]::SW_MINIMIZE) | Out-Null
        }
        return $true
    }, [IntPtr]::Zero)
}

###############################################################################
# 3. DEFINE RESTORE FUNCTION
###############################################################################
function Restore-System {
    Write-Host "`n--- RESTORING: Original wallpaper, icons, taskbar... ---`n"

    try {
        # Restore HideIcons
        if ($originalHideIcons -ne $null) {
            Set-ItemProperty -Path $hideIconsPath -Name "HideIcons" -Value $originalHideIcons
        } else {
            Set-ItemProperty -Path $hideIconsPath -Name "HideIcons" -Value 0
        }

        # Restore NoDesktop
        if ($originalNoDesktop -ne $null) {
            Set-ItemProperty -Path $policiesPath -Name "NoDesktop" -Value $originalNoDesktop
        } else {
            Set-ItemProperty -Path $policiesPath -Name "NoDesktop" -Value 0
        }

        # Restore original wallpaper, if it still exists
        if ($originalWallpaper -and (Test-Path $originalWallpaper)) {
            [WinAPI]::SystemParametersInfo(0x14, 0, $originalWallpaper, 0x1 -bor 0x2) | Out-Null
        }
        else {
            # Fallback to an online default or do nothing
            Write-Host "Original wallpaper not found, using fallback..."
            $fallbackUrl = "https://wallpapercave.com/wp/wp10128604.jpg" 
            $fallbackPath = "$env:USERPROFILE\Downloads\restoredWallpaper.jpg"
            (New-Object System.Net.WebClient).DownloadFile($fallbackUrl, $fallbackPath)
            [WinAPI]::SystemParametersInfo(0x14, 0, $fallbackPath, 0x1 -bor 0x2) | Out-Null
        }

        # Restore taskbar
        if ($originalStuckRects) {
            Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value $originalStuckRects
        } else {
            # If no original, default to '2' (show)
            $regKey = (Get-ItemProperty -Path $stuckRectsPath).Settings
            $regKey[8] = 2
            Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value $regKey
        }

        # Restart Explorer
        Get-Process explorer -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
        Start-Process explorer

        Write-Host "Restore complete."
    }
    catch {
        Write-Host "Error during restoration: $($_.Exception.Message)"
    }
}

###############################################################################
# 4. RUN THE PRANK
###############################################################################
Invoke-Prank

###############################################################################
# 5. WAIT FOR MOUSE MOVEMENT, THEN RESTORE
###############################################################################
Write-Host "Prank active. Move your mouse to restore..."

Add-Type -AssemblyName System.Windows.Forms  # for Cursor/MousePosition
$oldPos = [System.Windows.Forms.Cursor]::Position

while ($true) {
    Start-Sleep -Milliseconds 500
    $newPos = [System.Windows.Forms.Cursor]::Position
    if (($newPos.X -ne $oldPos.X) -or ($newPos.Y -ne $oldPos.Y)) {
        # Mouse moved
        Restore-System
        break
    }
}
