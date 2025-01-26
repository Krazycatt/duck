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

public class MouseHandler : Form
{
    private static bool isRestored = false;

    public MouseHandler()
    {
        // Make a borderless, topmost, nearly invisible form that covers the entire screen
        this.FormBorderStyle = FormBorderStyle.None;
        this.WindowState = FormWindowState.Maximized;
        this.TopMost = true;
        this.ShowInTaskbar = false;
        
        // Opacity must be > 0 to capture mouse events. 0.01 is effectively invisible
        this.Opacity = 0.01;

        // We'll use MouseMove to trigger restoration
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
                0);
            
            // Re-enable the desktop
            Microsoft.Win32.Registry.SetValue(
                @"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer",
                "NoDesktop",
                0);

            // Download and set a "normal" wallpaper
            string imageUrl = "https://wallpapercave.com/wp/wp10128604.jpg";
            string imagePath = Environment.GetEnvironmentVariable("USERPROFILE") + "\\Downloads\\normal.jpg";
            using (var client = new System.Net.WebClient())
            {
                client.DownloadFile(imageUrl, imagePath);
            }
            Win32.SystemParametersInfo(0x0014, 0, imagePath, 0x01 | 0x02);

            // Show taskbar
            string regPath = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3";
            using (var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(regPath, true))
            {
                if (key != null)
                {
                    byte[] settings = (byte[])key.GetValue("Settings");
                    settings[8] = 2;  // 2 => show taskbar
                    key.SetValue("Settings", settings);
                }
            }

            // Restart Explorer to apply changes
            foreach (var process in System.Diagnostics.Process.GetProcessesByName("explorer"))
            {
                process.Kill();
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
    # Kill specific Wallpaper Engine processes
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

    # Hide desktop icons
    $Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $Path -Name "HideIcons" -Value 1

    # Disable desktop
    $Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    If (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name "NoDesktop" -Value 1

    # Download BSOD image
    $imageUrl = "https://1.bp.blogspot.com/-fifVJfHz0-M/XDjD30_jWcI/AAAAAAAAAWM/HQ3Uv5ZHVCo37RbllK7v927DMYUl36TJgCLcBGAs/s1600/blue%2Bscreen%2Bof%2Bdeath%2Bwindow%2B10.png"
    $imagePath = "$env:USERPROFILE\Downloads\bsod.png"
    (New-Object System.Net.WebClient).DownloadFile($imageUrl, $imagePath)

    # Set as wallpaper (0x14 = SPI_SETDESKWALLPAPER, 0x1|0x2 = SPIF_UPDATEINIFILE|SPIF_SENDWININICHANGE)
    [Win32]::SystemParametersInfo(0x0014, 0, $imagePath, 0x01 -bor 0x02)

    # Hide taskbar
    $RegPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    $RegKey = (Get-ItemProperty -Path $RegPath).Settings
    $RegKey[8] = 3  # 3 => hide taskbar, 2 => show
    Set-ItemProperty -Path $RegPath -Name Settings -Value $RegKey

    # Restart explorer to apply changes
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer

    # Wait 6 seconds and kill specific processes again if they relaunched
    Start-Sleep -Seconds 6
    foreach ($processName in $processNames) {
        Stop-Process -Name $processName -Force -ErrorAction SilentlyContinue
    }

    # Minimize all windows
    $shell = New-Object -ComObject "Shell.Application"
    $shell.MinimizeAll()
}

# 1) Execute the prank
Do-Prank

# 2) Start the mouse-listening form to restore on movement
$form = New-Object MouseHandler
[System.Windows.Forms.Application]::Run($form)
