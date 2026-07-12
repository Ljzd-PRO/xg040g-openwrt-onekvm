[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$VMName,
    [Parameter(Mandatory)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class XgWindowCapture {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int command);

    public static IntPtr FindVisibleWindow(string titlePart) {
        IntPtr result = IntPtr.Zero;
        EnumWindows((hWnd, lParam) => {
            if (!IsWindowVisible(hWnd)) return true;
            StringBuilder title = new StringBuilder(1024);
            GetWindowText(hWnd, title, title.Capacity);
            if (title.ToString().IndexOf(titlePart, StringComparison.OrdinalIgnoreCase) >= 0) {
                result = hWnd;
                return false;
            }
            return true;
        }, IntPtr.Zero);
        return result;
    }
}
'@

$window = [XgWindowCapture]::FindVisibleWindow($VMName)
if ($window -eq [IntPtr]::Zero) {
    throw "VMConnect window not found for $VMName"
}

[void][XgWindowCapture]::ShowWindow($window, 9)
[void][XgWindowCapture]::SetForegroundWindow($window)
Start-Sleep -Milliseconds 750

$rect = [XgWindowCapture+RECT]::new()
if (-not [XgWindowCapture]::GetWindowRect($window, [ref]$rect)) {
    throw 'GetWindowRect failed'
}

$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top
if ($width -lt 100 -or $height -lt 100) {
    throw "Invalid VMConnect window dimensions: ${width}x${height}"
}

$parent = Split-Path -Parent $OutputPath
if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

$bitmap = [Drawing.Bitmap]::new($width, $height)
$graphics = [Drawing.Graphics]::FromImage($bitmap)
try {
    $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
    $bitmap.Save($OutputPath, [Drawing.Imaging.ImageFormat]::Png)
} finally {
    $graphics.Dispose()
    $bitmap.Dispose()
}

Get-Item $OutputPath | Select-Object FullName, Length, LastWriteTime
