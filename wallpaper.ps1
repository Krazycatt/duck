###############################################################################
# C# code: a single form that listens for mouse movement twice
###############################################################################
$code = @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class Win32 {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}

public class TwoStepMouseForm : Form
{
    private Action _prankAction;
    private Action _restoreAction;
    
    private bool didPrank   = false;
    private bool didRestore = false;

    public TwoStepMouseForm(Action prankAction, Action restoreAction)
    {
        _prankAction = prankAction;
        _restoreAction = restoreAction;

        // Fullscreen, topmost, nearly invisible form
        this.FormBorderStyle = FormBorderStyle.None;
        this.WindowState = FormWindowState.Maximized;
        this.TopMost = true;
        this.ShowInTaskbar = false;

        // Must be > 0 to receive mouse events
        this.Opacity = 0.01;

        // When mouse moves, we either do the prank (1st time)
        // or restore (2nd time).
        this.MouseMove += new MouseEventHandler(Form_MouseMove);
    }

    private void Form_MouseMove(object sender, MouseEventArgs e)
    {
        // 1st mouse move => do the prank
        if (!didPrank)
        {
            didPrank = true;
            _prankAction?.Invoke();
            return;
        }

        // 2nd mouse move => do the restore, then exit
        if (!didRestore)
        {
            didRestore = true;
            _restoreAction?.Invoke();
            Application.Exit();
        }
    }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies System.Windows.Forms

###############################################################################
# PRANK ACTION: Hide icons, BSOD wallpaper, hide taskbar, minimize windows
###############################################################################
function Invoke-Prank {
    Write-Host "`n--- PRANK: Setting BSOD, hiding icons/taskbar... ---`n"

    # 1) Hide desktop icons (HideIcons=1)
    $regPathIcons = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $regPathIcons -Name "HideIcons" -Value 1 -ErrorAction SilentlyContinue

    # 2) Download & set Fake BSOD wallpaper
    $bsodUrl  = "https://1.bp.blogspot.com/-fifVJfHz0-M/XDjD30_jWcI/AAAAAAAAAWM/HQ3Uv5ZHVCo37RbllK7v927DMYUl36TJgCLcBGAs/s1600/blue%2Bscreen%2Bof%2Bdeath%2Bwindow%2B10.png"
    $bsodPath = "$env:USERPROFILE\Downloads\bsod.png"
    (New-Object System.Net.WebClient).DownloadFile($bsodUrl, $bsodPath)

    [Win32]::SystemParametersInfo(0x14, 0, $bsodPath, 0x1 -bor 0x2) | Out-Null

    # 3) Hide taskbar (StuckRects3 => [8] = 3)
    $stuckRects = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    $srData = (Get-ItemProperty -Path $stuckRects -ErrorAction SilentlyContinue).Settings
    if ($srData) {
        $srData[8] = 3
        Set-ItemProperty -Path $stuckRects -Name Settings -Value $srData -ErrorAction SilentlyContinue
    }

    # 4) Restart Explorer
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer
    Start-Sleep 1

    # 5) Minimize all windows (original method)
    $shell = New-Object -ComObject "Shell.Application"
    $shell.MinimizeAll()
}

###############################################################################
# RESTORE ACTION: Show icons, normal wallpaper, show taskbar
###############################################################################
function Restore-System {
    Write-Host "`n--- RESTORE: Normal wallpaper, icons, taskbar... ---`n"

    # 1) Show desktop icons (HideIcons=0)
    $regPathIcons = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $regPathIcons -Name "HideIcons" -Value 0 -ErrorAction SilentlyContinue

    # 2) Download & set normal wallpaper
    #    (the "Windows-like" background you mentioned)
    $normalUrl  = "https://wallpapercave.com/wp/wp10128604.jpg"
    $normalPath = "$env:USERPROFILE\Downloads\normal.jpg"
    (New-Object System.Net.WebClient).DownloadFile($normalUrl, $normalPath)

    [Win32]::SystemParametersInfo(0x14, 0, $normalPath, 0x1 -bor 0x2) | Out-Null

    # 3) Show taskbar (StuckRects3 => [8] = 2)
    $stuckRects = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    $srData = (Get-ItemProperty -Path $stuckRects -ErrorAction SilentlyContinue).Settings
    if ($srData) {
        $srData[8] = 2
        Set-ItemProperty -Path $stuckRects -Name Settings -Value $srData -ErrorAction SilentlyContinue
    }

    # 4) Restart Explorer
    Get-Process explorer -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
    Start-Process explorer
    Write-Host "Restore complete."
}

###############################################################################
# MAIN LOGIC
###############################################################################
Write-Host "`nScript loaded. Move mouse ONCE to apply the FAKE BSOD, move mouse AGAIN to RESTORE.`n"
# We create the form that has two steps:
# - First mouse move => PRANK
# - Second mouse move => RESTORE
$form = New-Object TwoStepMouseForm ([System.Action] { Invoke-Prank }) ([System.Action] { Restore-System })
[System.Windows.Forms.Application]::Run($form)
