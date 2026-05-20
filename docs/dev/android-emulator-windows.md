# Android emulator window appears off-screen on Windows

## Symptom

You launch the Pixel 8 Pro AVD via `flutter emulators --launch Pixel_8_Pro` or directly via `emulator.exe`. The process spins up (you can see `qemu-system-x86_64.exe` consuming 2+ GB RAM in Task Manager, and `adb devices` shows `emulator-5554 device`), but the **emulator window is invisible** — you see only the taskbar icon, and clicking it doesn't bring up a window. Win+Tab / Alt+Tab may not show it either.

This happens on this Windows install reproducibly across sessions. Root cause: the emulator's saved window position is off-screen (likely from a previous multi-monitor session) and Windows doesn't auto-snap it back to the primary monitor.

## Fix (PowerShell, ~10 seconds)

After the emulator process is running, force-move its window onto the primary monitor and bring it to the foreground:

```powershell
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@
$proc = Get-Process | Where-Object { $_.MainWindowTitle -like "*Pixel_8_Pro*" } | Select-Object -First 1
if ($proc) {
  # X=120, Y=60, width=380, height=780  → phone-aspect, top-left of primary monitor
  [Win32]::SetWindowPos($proc.MainWindowHandle, [IntPtr]::Zero, 120, 60, 380, 780, 0x0040) | Out-Null
  [Win32]::ShowWindow($proc.MainWindowHandle, 9) | Out-Null   # SW_RESTORE
  [Win32]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
}
```

Adjust `380, 780` to taste — that's a comfortable phone-aspect size on a desktop monitor.

## Canonical launch sequence

```powershell
# 1. Kill any stuck emulator processes from a previous attempt
Stop-Process -Name qemu-system-x86_64 -Force -ErrorAction SilentlyContinue
Stop-Process -Name emulator -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# 2. Launch the AVD with cold-boot (skips the corrupt-snapshot trap)
Start-Process -FilePath "F:\mm\sdk\emulator\emulator.exe" `
  -ArgumentList "-avd","Pixel_8_Pro","-no-snapshot-load","-gpu","auto" `
  -WorkingDirectory "F:\mm\sdk\emulator"

# 3. Wait for boot to complete
$env:Path = "F:\mm\sdk\platform-tools;$env:Path"
do {
  Start-Sleep -Seconds 5
  $b = & adb -s emulator-5554 shell getprop sys.boot_completed 2>$null
} until ($b -match '1')

# 4. Force the window onto the primary monitor (see above)

# 5. From the project root, run the app on the emulator
cd H:\alnujom-project
flutter run --device-id=emulator-5554 --dart-define-from-file=.env.json --debug
```

## Why this matters

Without this fix, the emulator looks broken every time — the agent has to rediscover that the QEMU VM is healthy and only the window placement is wrong, then write the SetWindowPos call from scratch. Centralising it here means future sessions can paste the PowerShell snippet and move on within a minute.

## Related

- `project_dart_defines.md` memory — `--dart-define-from-file=.env.json` is mandatory or `Supabase.initialize` is skipped.
- `flutter doctor -v` reports the Android SDK at `F:\mm\sdk`. If that path ever changes, update the canonical launch sequence above.
