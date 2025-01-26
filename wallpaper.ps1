$code = @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class Win32 {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
}

public class KeyHandler : Form
{
    // We'll store references to the revert method from PowerShell
    private Action _restoreAction;

    public KeyHandler(Action restoreAction)
    {
        _restoreAction = restoreAction;

        this.WindowState = FormWindowState.Minimized;
        this.ShowInTaskbar = false;
        this.Opacity = 0;

        this.KeyPreview = true;
        this.KeyDown += new KeyEventHandler(Form_KeyDown);
    }

    private void Form_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Control && e.KeyCode == Keys.F)
        {
            // Call the restore action from PowerShell
            if (_restoreAction != null) {
                _restoreAction();
            }
            
            Application.Exit();
        }
    }
}
'@

Add-Type -TypeDefinition $code -ReferencedAssemblies System.Windows.Forms

# 1. Capture Current Settings
Write-Host "Capturing current wallpaper/registry settings..."

# The user’s current wallpaper path is often stored here:
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

# 2. Define function to hide everything (the 'prank' part)
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
        # Copy original array so we only change the index we need
        $newStuckRects = [byte[]]::new($originalStuckRects.Length)
        $originalStuckRects.CopyTo($newStuckRects, 0)

        # Typically byte index 8 changes taskbar autohide or show:
        # 2 => normal, 3 => hide
        $newStuckRects[8] = 3
        Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value $newStuckRects
    } else {
        # If not found, do a default approach
        $regKey = (Get-ItemProperty -Path $stuckRectsPath).Settings
        $regKey[8] = 3
        Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value $regKey
    }

    # Restart Explorer
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer

    # Minimize all windows
    Start-Sleep -Seconds 1
    $shell = New-Object -ComObject "Shell.Application"
    $shell.MinimizeAll()
}

# 3. Define function to restore everything
function Restore-System {
    try {
        Write-Host "Restoring old settings..."

        # Restore HideIcons
        if ($originalHideIcons -ne $null) {
            Set-ItemProperty -Path $hideIconsPath -Name "HideIcons" -Value $originalHideIcons
        } else {
            # In case nothing was found, default to 0
            Set-ItemProperty -Path $hideIconsPath -Name "HideIcons" -Value 0
        }

        # Restore NoDesktop
        if ($originalNoDesktop -ne $null) {
            Set-ItemProperty -Path $policiesPath -Name "NoDesktop" -Value $originalNoDesktop
        } else {
            # default to 0 if not found
            Set-ItemProperty -Path $policiesPath -Name "NoDesktop" -Value 0
        }

        # Restore original wallpaper
        if ($originalWallpaper -and (Test-Path $originalWallpaper)) {
            [Win32]::SystemParametersInfo(0x14, 0, $originalWallpaper, 0x1 -bor 0x2)
        } else {
            # If the old file doesn't exist for some reason, you could:
            # 1) do nothing, or
            # 2) set a built-in Windows default wallpaper
            Write-Host "Original wallpaper path not found or doesn't exist. Using fallback."
            
            # Example fallback
            $fallbackUrl = "https://wallpapercave.com/wp/wp10128604.jpg"
            $fallbackPath = "$env:USERPROFILE\Downloads\normal.jpg"
            (New-Object System.Net.WebClient).DownloadFile($fallbackUrl, $fallbackPath)
            [Win32]::SystemParametersInfo(0x14, 0, $fallbackPath, 0x1 -bor 0x2)
        }

        # Restore taskbar
        if ($originalStuckRects) {
            # Simply revert to the original array
            Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value $originalStuckRects
        } else {
            # If we had no original, default to '2' (shown)
            $regKey = (Get-ItemProperty -Path $stuckRectsPath).Settings
            $regKey[8] = 2
            Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value $regKey
        }

        # Restart Explorer
        foreach ($p in (Get-Process explorer -ErrorAction SilentlyContinue)) {
            $p.Kill()
        }
        Start-Process explorer

        Write-Host "Restore complete."
    }
    catch {
        Write-Host "Error during restoration: $($_.Exception.Message)"
    }
}

# 4. Actually run the prank now
Invoke-Prank

# 5. Create the form with the restore callback
$restoreDelegate = [System.Action] { Restore-System }
$form = New-Object KeyHandler($restoreDelegate)
[System.Windows.Forms.Application]::Run($form)
