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
        // Create a full-screen, topmost, nearly invisible form to capture mouse movement
        this.FormBorderStyle = FormBorderStyle.None;
        this.WindowState = FormWindowState.Maximized;
        this.TopMost = true;
        this.ShowInTaskbar = false;

        // Must be > 0 to capture mouse events
        this.Opacity = 0.01;

        // Fire restore on mouse movement
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
            // Show desktop icons (HideIcons = 0)
            Microsoft.Win32.Registry.SetValue(
                @"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced",
                "HideIcons",
                0
            );

            // Re-enable the desktop (NoDesktop = 0)
            Microsoft.Win32.Registry.SetValue(
                @"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer",
                "NoDesktop",
                0
            );

            // Download and set normal wallpaper
            string imageUrl = "https://wallpapercave.com/wp/wp10128604.jpg";
            string imagePath = Environment.GetEnvironmentVariable("USERPROFILE") + "\\Downloads\\normal.jpg";
            using (var wc = new System.Net.WebClient())
            {
                wc.DownloadFile(imageUrl, imagePath);
            }
            Win32.SystemParametersInfo(0x14, 0, imagePath, 0x1 | 0x2);

            // Show the taskbar (StuckRects3 => [8] = 2)
            string regPath = @"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3";
            byte[] settings = (byte[])Microsoft.Win32.Registry.GetValue(regPath, "Settings", null);
            if (settings != null)
            {
                settings[8] = 2;
                Microsoft.Win32.Registry.SetValue(regPath, "Settings", settings);
            }

            // Restart Explorer
            var explorers = System.Diagnostics.Process.GetProcessesByName("explorer");
            foreach (var ex in explorers)
            {
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
    # 1) Kill known Wallpaper Engine processes (optional)
    $processNames = @("wallpaper64","wallpaper32","webwallpaper64","webwallpaper32","wallpaperservice32")
    foreach ($proc in $processNames) {
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep 1

    # 2) Hide desktop icons
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideIcons" -Value 1

    # 3) Disable the desktop (NoDesktop = 1)
    $policiesPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    if (!(Test-Path $policiesPath)) {
        New-Item -Path $policiesPath | Out-Null
    }
    Set-ItemProperty -Path $policiesPath -Name "NoDesktop" -Value 1

    # 4) Download BSOD image
    $bsodUrl  = "https://1.bp.blogspot.com/-fifVJfHz0-M/XDjD30_jWcI/AAAAAAAAAWM/HQ3Uv5ZHVCo37RbllK7v927DMYUl36TJgCLcBGAs/s1600/blue%2Bscreen%2Bof%2Bdeath%2Bwindow%2B10.png"
    $bsodPath = "$env:USERPROFILE\Downloads\bsod.png"
    (New-Object System.Net.WebClient).DownloadFile($bsodUrl, $bsodPath)

    # 5) Set BSOD as wallpaper
    [Win32]::SystemParametersInfo(0x14, 0, $bsodPath, 0x1 -bor 0x2)

    # 6) Hide the taskbar ([8] = 3)
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    $srData  = (Get-ItemProperty -Path $regPath).Settings
    $srData[8] = 3
    Set-ItemProperty -Path $regPath -Name Settings -Value $srData

    # 7) Restart Explorer to apply changes
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer

    # 8) Pause briefly, then minimize all windows
    Start-Sleep -Seconds 2
    $shell = New-Object -ComObject "Shell.Application"
    $shell.MinimizeAll()
}

# -- 1) Execute the prank --
Do-Prank

# -- 2) Run the invisible form that restores on mouse movement --
$form = New-Object MouseHandler
[System.Windows.Forms.Application]::Run($form)
