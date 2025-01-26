$code = @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class Win32 {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}

public class MouseHandler : Form
{
    private static bool isRestored = false;

    public MouseHandler()
    {
        // Full-screen, topmost, nearly invisible window to detect mouse movement.
        this.FormBorderStyle = FormBorderStyle.None;
        this.WindowState = FormWindowState.Maximized;
        this.TopMost = true;
        this.ShowInTaskbar = false;

        // Opacity must be > 0 to capture mouse events
        this.Opacity = 0.01;

        // If the mouse moves, restore the system
        this.MouseMove += new MouseEventHandler(Form_MouseMove);
    }

    private void Form_MouseMove(object sender, MouseEventArgs e)
    {
        if (!isRestored)
        {
            isRestored = true;
            RestoreSystem();
            Application.Exit();
        }
    }

    private void RestoreSystem()
    {
        try
        {
            // Show desktop icons
            Microsoft.Win32.Registry.SetValue(
                @"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced",
                "HideIcons",
                0
            );

            // Re-enable the desktop
            // WARNING: If you lack permission to this key, you'll get "Access Denied".
            //          Remove or comment out if it fails on your system.
            Microsoft.Win32.Registry.SetValue(
                @"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer",
                "NoDesktop",
                0
            );

            // Set a normal wallpaper
            string normalUrl = "https://wallpapercave.com/wp/wp10128604.jpg";
            string normalPath = Environment.GetEnvironmentVariable("USERPROFILE") + "\\Downloads\\normal.jpg";
            using (var wc = new System.Net.WebClient()) {
                wc.DownloadFile(normalUrl, normalPath);
            }
            Win32.SystemParametersInfo(0x14, 0, normalPath, 0x1 | 0x2);

            // Show the taskbar
            string stuckRects = @"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3";
            byte[] srData = (byte[])Microsoft.Win32.Registry.GetValue(stuckRects, "Settings", null);
            if (srData != null) {
                // 2 => show taskbar, 3 => hide
                srData[8] = 2;
                Microsoft.Win32.Registry.SetValue(stuckRects, "Settings", srData);
            }

            // Restart Explorer
            var explorers = System.Diagnostics.Process.GetProcessesByName("explorer");
            foreach (var ex in explorers) {
                ex.Kill();
            }
            System.Diagnostics.Process.Start("explorer.exe");
        }
        catch (Exception ex)
        {
            MessageBox.Show("Error during restoration: " + ex.Message);
        }
    }
}
'@

Add-Type -TypeDefinition $code -ReferencedAssemblies System.Windows.Forms

function Do-Prank {

    # 1) Kill common Wallpaper Engine processes (optional)
    $processNames = @("wallpaper64","wallpaper32","webwallpaper64","webwallpaper32","wallpaperservice32")
    foreach ($proc in $processNames) {
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep 1

    # 2) Hide desktop icons
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideIcons" -Value 1

    # 3) Disable the desktop
    #    If you get an access error here, comment this out.
    $policiesKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    if (!(Test-Path $policiesKey)) {
        New-Item -Path $policiesKey | Out-Null
    }
    Set-ItemProperty -Path $policiesKey -Name "NoDesktop" -Value 1

    # 4) Download & set Fake BSOD wallpaper
    $bsodUrl  = "https://1.bp.blogspot.com/-fifVJfHz0-M/XDjD30_jWcI/AAAAAAAAAWM/HQ3Uv5ZHVCo37RbllK7v927DMYUl36TJgCLcBGAs/s1600/blue%2Bscreen%2Bof%2Bdeath%2Bwindow%2B10.png"
    $bsodPath = "$env:USERPROFILE\Downloads\bsod.png"
    (New-Object System.Net.WebClient).DownloadFile($bsodUrl, $bsodPath)
    [Win32]::SystemParametersInfo(0x14, 0, $bsodPath, 0x1 -bor 0x2) | Out-Null

    # 5) Hide the taskbar via StuckRects3 ([8] = 3)
    $stuckRectsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    $srData = (Get-ItemProperty -Path $stuckRectsPath).Settings
    $srData[8] = 3
    Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value $srData

    # 6) Restart Explorer
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer
    Start-Sleep 1

    # 7) Minimize all open windows
    $shell = New-Object -ComObject "Shell.Application"
    $shell.MinimizeAll()
}

# ---- RUN THE PRANK ----
Do-Prank

# ---- WAIT FOR MOUSE MOVEMENT TO RESTORE ----
$form = New-Object MouseHandler
[System.Windows.Forms.Application]::Run($form)
