$code = @'
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@

Add-Type -TypeDefinition $code

# Download normal wallpaper
$imageUrl = "https://wallpapercave.com/wp/wp10128604.jpg"
$imagePath = "$env:USERPROFILE\Downloads\normal.jpg"
(New-Object System.Net.WebClient).DownloadFile($imageUrl, $imagePath)

# Set as wallpaper
[Win32]::SystemParametersInfo(0x0014, 0, $imagePath, 0x01 -bor 0x02)

# Show taskbar
$RegPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
$RegKey = (Get-ItemProperty -Path $RegPath).Settings
$RegKey[8] = 2  # Show taskbar
Set-ItemProperty -Path $RegPath -Name Settings -Value $RegKey

# Restart explorer to apply taskbar change
Stop-Process -Name explorer -Force
Start-Process explorer
