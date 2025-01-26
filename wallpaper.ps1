$code = @'
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
'@

Add-Type -TypeDefinition $code

# Function to perform BSOD setup
function Set-BSODPrank {
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
    $Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    If (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name "NoDesktop" -Value 1

    # Download BSOD image
    $imageUrl = "https://1.bp.blogspot.com/-fifVJfHz0-M/XDjD30_jWcI/AAAAAAAAAWM/HQ3Uv5ZHVCo37RbllK7v927DMYUl36TJgCLcBGAs/s1600/blue%2Bscreen%2Bof%2Bdeath%2Bwindow%2B10.png"
    $imagePath = "$env:USERPROFILE\Downloads\bsod.png"
    (New-Object System.Net.WebClient).DownloadFile($imageUrl, $imagePath)

    # Set as wallpaper
    [Win32]::SystemParametersInfo(0x0014, 0, $imagePath, 0x01 -bor 0x02)

    # Hide taskbar
    $RegPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    $RegKey = (Get-ItemProperty -Path $RegPath).Settings
    $RegKey[8] = 3  # Hide taskbar
    Set-ItemProperty -Path $RegPath -Name Settings -Value $RegKey

    # Restart explorer to apply all changes
    Stop-Process -Name explorer -Force
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

# Function to restore everything
function Restore-Desktop {
    # Show desktop icons
    $Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $Path -Name "HideIcons" -Value 0
    $Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    Set-ItemProperty -Path $Path -Name "NoDesktop" -Value 0

    # Download and set normal wallpaper
    $imageUrl = "https://wallpapercave.com/wp/wp10128604.jpg"
    $imagePath = "$env:USERPROFILE\Downloads\normal.jpg"
    (New-Object System.Net.WebClient).DownloadFile($imageUrl, $imagePath)
    [Win32]::SystemParametersInfo(0x0014, 0, $imagePath, 0x01 -bor 0x02)

    # Show taskbar
    $RegPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    $RegKey = (Get-ItemProperty -Path $RegPath).Settings
    $RegKey[8] = 2  # Show taskbar
    Set-ItemProperty -Path $RegPath -Name Settings -Value $RegKey

    # Restart explorer to apply changes
    Stop-Process -Name explorer -Force
    Start-Process explorer
}

# Run the BSOD prank
Set-BSODPrank

# Add the keyboard hook to monitor for "fix"
Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class KeyLogger {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;

    private static IntPtr hookId = IntPtr.Zero;
    private static string buffer = "";
    private static HookProc hookProc;

    [DllImport("user32.dll")]
    private static extern IntPtr SetWindowsHookEx(int idHook, HookProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll")]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    public delegate IntPtr HookProc(int code, IntPtr wParam, IntPtr lParam);

    public static void Start() {
        hookProc = HookCallback;
        hookId = SetHook(hookProc);
        Application.Run();
    }

    private static IntPtr SetHook(HookProc proc) {
        using (Process curProcess = Process.GetCurrentProcess())
        using (ProcessModule curModule = curProcess.MainModule) {
            return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
            int vkCode = Marshal.ReadInt32(lParam);
            buffer += (Keys)vkCode;
            if (buffer.Length > 4) buffer = buffer.Substring(1);
            if (buffer.ToLower().Contains("fix")) {
                UnhookWindowsHookEx(hookId);
                Application.Exit();
            }
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
}
"@

# Start monitoring for "fix" in a separate thread
$monitorJob = Start-Job -ScriptBlock {
    [System.Windows.Forms.Application]::EnableVisualStyles()
    [KeyLogger]::Start()
}

# Wait for the "fix" keyword to be typed
Wait-Job $monitorJob

# Run the restore function when "fix" is detected
Restore-Desktop
