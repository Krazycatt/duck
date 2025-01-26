###############################################################################
# C# code to create a hidden form that triggers restore on mouse movement
###############################################################################
$code = @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class Win32 {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}

public class MouseMoveForm : Form
{
    private Action _restoreAction;
    private bool _restored = false;

    public MouseMoveForm(Action restoreAction)
    {
        _restoreAction = restoreAction;

        // Make a borderless, topmost, (almost) invisible form
        this.FormBorderStyle = FormBorderStyle.None;
        this.WindowState = FormWindowState.Maximized; // covers the whole primary screen
        this.TopMost = true;
        this.ShowInTaskbar = false;
        
        // Setting Opacity to 0.01 so we can still receive mouse events
        this.Opacity = 0.01;

        // Subscribe to the MouseMove event
        this.MouseMove += new MouseEventHandler(Form_MouseMove);
    }

    private void Form_MouseMove(object sender, MouseEventArgs e)
    {
        if (!_restored)
        {
            _restored = true;
            _restoreAction();
            Application.Exit();
        }
    }
}
'@

Add-Type -TypeDefinition $code -ReferencedAssemblies System.Windows.Forms

###############################################################################
# 1. Capture Current Settings
###############################################################################
Write-Host "Capturing current wallpaper/registry settings..."

# The user’s current wallpaper path is stored here:
$originalWallpaper = (Get-ItemProperty "HKCU:\Control Panel\Desktop").WallPaper

# HideIcons
$hideIconsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
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

Write-Host "Original Wallpaper: $originalWallpaper"
Write-Host "Original HideIcons: $originalHideIcons"
Write-Host "Original NoDesktop: $originalNoDesktop"
Write-Host "Original StuckRects3: $($originalStuckRects -join ',')"

###############################################################################
# 2. Define function to hide everything (the 'prank' part)
###############################################################################
function Invoke-Prank {
    # (Optional) Kill known Wallpaper Engine processes
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

    Start-Sleep -Seconds 1

    # Hide desktop icons
    Set-ItemProperty -Path $hideIconsPath -Name "HideIcons" -Value 1

    # Disable desktop
    Set-ItemProperty -Path $policiesPath -Name "NoDesktop" -Value 1

    # Download Fake BSOD
    $fakeBSODUrl = "https://1.bp.blogspot.com/-fifVJfHz0-M/XDjD30_jWcI/AAAAAAAAAWM/HQ3Uv5ZHVCo37RbllK7v927DMYUl36TJgCLcBGAs/s1600/blue%2Bscreen%2Bof%2Bdeath%2Bwindow%2B10.png"
    $bsodImagePath = "$env:USERPROFILE\Downloads\bsod.png"
    try {
        (New-Object System.Net.WebClient).DownloadFile($fakeBSODUrl, $bsodImagePath)
    } catch {
        Write-Host "Failed to download BSOD image: $($_.Exception.Message)"
    }

    # Set wallpaper to fake BSOD
    [Win32]::SystemParametersInfo(0x14, 0, $bsodImagePath, 0x1 -bor 0x2)

    # Hide taskbar
    if ($originalStuckRects) {
        # Copy the original array so we only change the index we need
        $newStuckRects = [byte[]]::new($originalStuckRects.Length)
        $originalStuckRects.CopyTo($newStuckRects, 0)

        # Typically byte index 8 controls taskbar autohide/show:
        # 2 => normal, 3 => hide
        $newStuckRects[8] = 3
        Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value $newStuckRects
    } else {
        # If not found, do a naive approach
        $regKey = (Get-ItemProperty -Path $stuckRectsPath).Settings
        $regKey[8] = 3
        Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value $regKey
    }

    # Restart Explorer
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer

    # Minimize all windows (optional)
    Start-Sleep -Seconds 1
    $shell = New-Object -ComObject "Shell.Application"
    $shell.MinimizeAll()
}

###############################################################################
# 3. Define function to restore everything
###############################################################################
function Restore-System {
    try {
        Write-Host "Restoring old settings..."

        # Restore HideIcons
        if ($originalHideIcons -ne $null) {
            Set-ItemProperty -Path $hideIconsPath -Name "HideIcons" -Value $originalHideIcons
        } else {
            # If not found, default to 0
            Set-ItemProperty -Path $hideIconsPath -Name "HideIcons" -Value 0
        }

        # Restore NoDesktop
        if ($originalNoDesktop -ne $null) {
            Set-ItemProperty -Path $policiesPath -Name "NoDesktop" -Value $originalNoDesktop
        } else {
            # If not found, default to 0
            Set-ItemProperty -Path $policiesPath -Name "NoDesktop" -Value 0
        }

        # Restore original wallpaper
        if ($originalWallpaper -and (Test-Path $originalWallpaper)) {
            [Win32]::SystemParametersInfo(0x14, 0, $originalWallpaper, 0x1 -bor 0x2)
        } else {
            # If the old file doesn't exist for some reason, you could:
            # 1) do nothing, or
            # 2) set a fallback wallpaper
            Write-Host "Original wallpaper file not found, using fallback wallpaper..."

            $fallbackUrl = "https://wallpapercave.com/wp/wp10128604.jpg" # Windows-like default
            $fallbackPath = "$env:USERPROFILE\Downloads\normal.jpg"
            (New-Object System.Net.WebClient).DownloadFile($fallbackUrl, $fallbackPath)
            [Win32]::SystemParametersInfo(0x14, 0, $fallbackPath, 0x1 -bor 0x2)
        }

        # Restore taskbar (StuckRects3)
        if ($originalStuckRects) {
            # Revert to the original array
            Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value $originalStuckRects
        } else {
            # If we had no original, default to '2' (shown)
            $regKey = (Get-ItemProperty -Path $stuckRectsPath).Settings
            $regKey[8] = 2
            Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value $regKey
        }

        # Restart Explorer to apply changes
        Get-Process explorer -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
        Start-Process explorer

        Write-Host "Restore complete."
    }
    catch {
        Write-Host "Error during restoration: $($_.Exception.Message)"
    }
}

###############################################################################
# 4. Actually run the prank
###############################################################################
Invoke-Prank

###############################################################################
# 5. Create the invisible form that will restore on mouse movement
###############################################################################
$restoreDelegate = [System.Action] { Restore-System }
$form = New-Object MouseMoveForm($restoreDelegate)
[System.Windows.Forms.Application]::Run($form)
