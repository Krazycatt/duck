###############################################################################
# 1) C# code for invisible form that triggers "Restore-System" on mouse move
###############################################################################
$code = @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class Win32 {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}

public class MouseForm : Form
{
    private readonly Action _restoreAction;
    private bool _restored = false;

    public MouseForm(Action restoreAction)
    {
        _restoreAction = restoreAction;

        // Fullscreen, topmost, nearly invisible window
        this.FormBorderStyle = FormBorderStyle.None;
        this.WindowState = FormWindowState.Maximized;
        this.TopMost = true;
        this.ShowInTaskbar = false;
        this.Opacity = 0.01; // Must be >0 for mouse events

        // Trigger restore when mouse moves anywhere in this form
        this.MouseMove += new MouseEventHandler(Form_MouseMove);
    }

    private void Form_MouseMove(object sender, MouseEventArgs e)
    {
        if (!_restored)
        {
            _restored = true;
            _restoreAction?.Invoke();
            Application.Exit();
        }
    }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies System.Windows.Forms

###############################################################################
# 2) PRANK: Hide Icons, Fake BSOD, Hide Taskbar
###############################################################################
function Invoke-Prank {
    # 2.1) Kill Wallpaper Engine (optional)
    $processNames = @("wallpaper64","wallpaper32","webwallpaper64","webwallpaper32","wallpaperservice32")
    foreach ($proc in $processNames) {
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep 1

    # 2.2) Hide desktop icons (HideIcons=1)
    $regPathIcons = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $regPathIcons -Name "HideIcons" -Value 1 -ErrorAction SilentlyContinue

    # 2.3) Download & set Fake BSOD wallpaper
    $fakeUrl = "https://1.bp.blogspot.com/-fifVJfHz0-M/XDjD30_jWcI/AAAAAAAAAWM/HQ3Uv5ZHVCo37RbllK7v927DMYUl36TJgCLcBGAs/s1600/blue%2Bscreen%2Bof%2Bdeath%2Bwindow%2B10.png"
    $fakePath = "$env:USERPROFILE\Downloads\bsod.png"
    try {
        (New-Object System.Net.WebClient).DownloadFile($fakeUrl, $fakePath)
    } catch {
        Write-Host "BSOD image download failed: $($_.Exception.Message)"
    }

    [Win32]::SystemParametersInfo(0x14, 0, $fakePath, 0x1 -bor 0x2) | Out-Null

    # 2.4) Hide the taskbar (StuckRects3 => [8] = 3)
    $stuckRects = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    $srData = (Get-ItemProperty -Path $stuckRects -ErrorAction SilentlyContinue).Settings
    if ($srData) {
        $srData[8] = 3
        Set-ItemProperty -Path $stuckRects -Name Settings -Value $srData -ErrorAction SilentlyContinue
    }

    # 2.5) Restart Explorer
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer
    Start-Sleep 1

    # 2.6) Minimize all windows
    $shell = New-Object -ComObject "Shell.Application"
    $shell.MinimizeAll()
}

###############################################################################
# 3) RESTORE: Show Icons, Normal Wallpaper, Show Taskbar
###############################################################################
function Restore-System {
    Write-Host "Restoring system..."

    # 3.1) Show desktop icons (HideIcons=0)
    $regPathIcons = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $regPathIcons -Name "HideIcons" -Value 0 -ErrorAction SilentlyContinue

    # 3.2) Download & set normal wallpaper
    $normalUrl = "https://wallpapercave.com/wp/wp10128604.jpg"
    $normalPath = "$env:USERPROFILE\Downloads\normal.jpg"
    try {
        (New-Object System.Net.WebClient).DownloadFile($normalUrl, $normalPath)
    } catch {
        Write-Host "Normal wallpaper download failed: $($_.Exception.Message)"
    }

    [Win32]::SystemParametersInfo(0x14, 0, $normalPath, 0x1 -bor 0x2) | Out-Null

    # 3.3) Show the taskbar (StuckRects3 => [8] = 2)
    $stuckRects = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    $srData = (Get-ItemProperty -Path $stuckRects -ErrorAction SilentlyContinue).Settings
    if ($srData) {
        $srData[8] = 2
        Set-ItemProperty -Path $stuckRects -Name Settings -Value $srData -ErrorAction SilentlyContinue
    }

    # 3.4) Restart Explorer
    Get-Process explorer -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
    Start-Process explorer

    Write-Host "Restore complete."
}

###############################################################################
# 4) RUN THE PRANK, THEN WAIT FOR MOUSE MOVE
###############################################################################
Invoke-Prank

$restoreDelegate = [System.Action] { Restore-System }
$form = New-Object MouseForm($restoreDelegate)
[System.Windows.Forms.Application]::Run($form)
