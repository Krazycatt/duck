###############################################################################
# 1) C# code for an invisible form that triggers RESTORE on mouse movement
###############################################################################
$code = @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class Win32 {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}

// Renamed "KeyHandler" to "MouseForm" to reflect it's capturing mouse movement
public class MouseForm : Form
{
    private Action _restoreAction;
    private bool _restored = false;

    public MouseForm(Action restoreAction)
    {
        _restoreAction = restoreAction;

        // We need a full-screen, topmost, nearly invisible form 
        // to reliably capture mouse movement over the primary monitor
        this.FormBorderStyle = FormBorderStyle.None;
        this.WindowState = FormWindowState.Maximized;
        this.TopMost = true;
        this.ShowInTaskbar = false;

        // Must be > 0 to receive mouse events
        this.Opacity = 0.01;

        // Trigger RESTORE when mouse moves
        this.MouseMove += new MouseEventHandler(Form_MouseMove);
    }

    private void Form_MouseMove(object sender, MouseEventArgs e)
    {
        if (!_restored)
        {
            _restored = true;
            if (_restoreAction != null) {
                _restoreAction();
            }
            Application.Exit();
        }
    }
}
'@

Add-Type -TypeDefinition $code -ReferencedAssemblies System.Windows.Forms

###############################################################################
# 2) CAPTURE CURRENT SETTINGS (Wallpaper, HideIcons, NoDesktop, Taskbar)
###############################################################################
Write-Host "Capturing current wallpaper/registry settings..."

$originalWallpaper = (Get-ItemProperty "HKCU:\Control Panel\Desktop").WallPaper -ErrorAction SilentlyContinue

$hideIconsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$originalHideIcons = (Get-ItemProperty -Path $hideIconsPath -Name "HideIcons" -ErrorAction SilentlyContinue).HideIcons

$policiesPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
if (!(Test-Path $policiesPath)) {
    New-Item -Path $policiesPath -Force | Out-Null
}
$originalNoDesktop = (Get-ItemProperty -Path $policiesPath -Name "NoDesktop" -ErrorAction SilentlyContinue).NoDesktop

$stuckRectsPath   = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
$originalStuckRects = (Get-ItemProperty -Path $stuckRectsPath -Name "Settings" -ErrorAction SilentlyContinue).Settings

Write-Host "Original Wallpaper: $originalWallpaper"
Write-Host "Original HideIcons: $originalHideIcons"
Write-Host "Original NoDesktop: $originalNoDesktop"
Write-Host "Original StuckRects3: $($originalStuckRects -join ',')"

###############################################################################
# 3) PRANK FUNCTION: Hide icons, disable desktop, fake BSOD, hide taskbar
###############################################################################
function Invoke-Prank {
    # Optionally kill Wallpaper Engine processes
    $processNames = @("wallpaper64","wallpaper32","webwallpaper64","webwallpaper32","wallpaperservice32")
    foreach ($pName in $processNames) {
        Stop-Process -Name $pName -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep 1

    # Hide desktop icons
    Set-ItemProperty -Path $hideIconsPath -Name "HideIcons" -Value 1 -ErrorAction SilentlyContinue

    # Disable desktop (NoDesktop=1) -- might fail on some systems if locked down
    Set-ItemProperty -Path $policiesPath -Name "NoDesktop" -Value 1 -ErrorAction SilentlyContinue

    # Download & set fake BSOD wallpaper
    $fakeBSODUrl  = "https://1.bp.blogspot.com/-fifVJfHz0-M/XDjD30_jWcI/AAAAAAAAAWM/HQ3Uv5ZHVCo37RbllK7v927DMYUl36TJgCLcBGAs/s1600/blue%2Bscreen%2Bof%2Bdeath%2Bwindow%2B10.png"
    $bsodPath = "$env:USERPROFILE\Downloads\bsod.png"
    try {
        (New-Object System.Net.WebClient).DownloadFile($fakeBSODUrl, $bsodPath)
    } catch {
        Write-Host "Failed to download BSOD image: $($_.Exception.Message)"
    }

    [Win32]::SystemParametersInfo(0x14, 0, $bsodPath, 0x1 -bor 0x2) | Out-Null

    # Hide taskbar (StuckRects3 => [8] = 3)
    if ($originalStuckRects) {
        $newSR = [byte[]]::new($originalStuckRects.Length)
        $originalStuckRects.CopyTo($newSR, 0)
        $newSR[8] = 3
        Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value $newSR -ErrorAction SilentlyContinue
    }
    else {
        $regVal = (Get-ItemProperty -Path $stuckRectsPath -ErrorAction SilentlyContinue).Settings
        if ($regVal) {
            $regVal[8] = 3
            Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value $regVal -ErrorAction SilentlyContinue
        }
    }

    # Restart Explorer
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer
    Start-Sleep 1

    # Minimize all windows
    $shell = New-Object -ComObject "Shell.Application"
    $shell.MinimizeAll()
}

###############################################################################
# 4) RESTORE FUNCTION: Undo each change, revert to original wallpaper if present
###############################################################################
function Restore-System {
    Write-Host "Restoring old settings..."
    # We'll do each step in a try block, but no .NET messagebox. Just silently fail if locked.

    # Show icons
    Set-ItemProperty -Path $hideIconsPath -Name "HideIcons" -Value $originalHideIcons -ErrorAction SilentlyContinue

    # Re-enable desktop (NoDesktop=0 or originalNoDesktop)
    if ($originalNoDesktop -ne $null) {
        Set-ItemProperty -Path $policiesPath -Name "NoDesktop" -Value $originalNoDesktop -ErrorAction SilentlyContinue
    } else {
        Set-ItemProperty -Path $policiesPath -Name "NoDesktop" -Value 0 -ErrorAction SilentlyContinue
    }

    # Restore wallpaper if the file still exists, otherwise use fallback
    if ($originalWallpaper -and (Test-Path $originalWallpaper)) {
        [Win32]::SystemParametersInfo(0x14, 0, $originalWallpaper, 0x1 -bor 0x2) | Out-Null
    }
    else {
        Write-Host "Original wallpaper not found; using fallback..."
        $fallbackUrl = "https://wallpapercave.com/wp/wp10128604.jpg"
        $fallbackPath = "$env:USERPROFILE\Downloads\normal.jpg"
        (New-Object System.Net.WebClient).DownloadFile($fallbackUrl, $fallbackPath)
        [Win32]::SystemParametersInfo(0x14, 0, $fallbackPath, 0x1 -bor 0x2) | Out-Null
    }

    # Show taskbar (StuckRects3 => [8] = 2) if originalStuckRects was known
    if ($originalStuckRects) {
        Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value $originalStuckRects -ErrorAction SilentlyContinue
    } else {
        $regVal2 = (Get-ItemProperty -Path $stuckRectsPath -ErrorAction SilentlyContinue).Settings
        if ($regVal2) {
            $regVal2[8] = 2
            Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value $regVal2 -ErrorAction SilentlyContinue
        }
    }

    # Restart Explorer
    Get-Process explorer -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
    Start-Process explorer
    Write-Host "Restore complete."
}

###############################################################################
# 5) RUN THE PRANK AND THEN THE 'MOUSEFORM' TO CAPTURE MOUSE MOVEMENT
###############################################################################
Invoke-Prank

# Create a delegate for restore
$restoreDelegate = [System.Action] { Restore-System }

# Create the invisible form that triggers restore on mouse movement
$form = New-Object MouseForm($restoreDelegate)
[System.Windows.Forms.Application]::Run($form)
