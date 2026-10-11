using System;
using System.Runtime.InteropServices;

/// <summary>
/// Makes the game window borderless, always-on-top, and transparent
/// via a color-key (LWA_COLORKEY). The camera must clear to the SAME key color.
/// Default key: magenta (255, 0, 255) -> Camera.clearFlags SolidColor (1,0,1,1).
/// Build target must be Windows x86_64.
/// </summary>
public static class NativeWindow
{
    const int GWL_EXSTYLE = -20;
    const int GWL_STYLE = -16;

    const int WS_EX_LAYERED = 0x00080000;
    const int WS_CAPTION = 0x00C00000;
    const int WS_THICKFRAME = 0x00040000;
    const int WS_MINIMIZEBOX = 0x00020000;
    const int WS_MAXIMIZEBOX = 0x00010000;

    const int LWA_COLORKEY = 0x00000001;

    static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    const uint SWP_NOMOVE = 0x0002;
    const uint SWP_NOSIZE = 0x0001;
    const uint SWP_SHOWWINDOW = 0x0040;

    [DllImport("user32.dll")]
    static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll")]
    static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    static extern bool SetLayeredWindowAttributes(IntPtr hwnd, uint crKey, byte bAlpha, uint dwFlags);

    /// <summary>Apply borderless + topmost + color-key transparency.</summary>
    public static void ApplyTransparent(IntPtr hwnd, byte r, byte g, byte b)
    {
        if (hwnd == IntPtr.Zero) return;

        int style = GetWindowLong(hwnd, GWL_STYLE);
        style &= ~WS_CAPTION;
        style &= ~WS_THICKFRAME;
        style &= ~WS_MINIMIZEBOX;
        style &= ~WS_MAXIMIZEBOX;
        SetWindowLong(hwnd, GWL_STYLE, style);

        int ex = GetWindowLong(hwnd, GWL_EXSTYLE);
        SetWindowLong(hwnd, GWL_EXSTYLE, ex | WS_EX_LAYERED);

        // COLORREF is 0x00BBGGRR
        uint key = ((uint)r) | ((uint)g << 8) | ((uint)b << 16);
        SetLayeredWindowAttributes(hwnd, key, 0, LWA_COLORKEY);

        SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
    }
}
