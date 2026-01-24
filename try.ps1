Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class Win32 {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
}
"@

# 1. Get handle of active window
$hWnd = [Win32]::GetForegroundWindow()

# 2. Create string buffer
$sb = New-Object System.Text.StringBuilder 1024

# 3. Call GetWindowText
[Win32]::GetWindowText($hWnd, $sb, $sb.Capacity) | Out-Null

# 4. Print window title
$sb.ToString()
