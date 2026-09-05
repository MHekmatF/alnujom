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

## Open: "too many emulator instances" — blocked since 2026-09-04

The AVD stopped starting at all. Every launch dies within seconds on:

```
ERROR        | It seems too many emulator instances are running on this machine. Aborting.
```

**with no emulator running.** Confirmed each time: no `qemu-system-x86_64` and no
`emulator` process, and `adb devices` listing only the physical Infinix.

Ruled out, in this order:

- **Not the window-placement problem above** — the process exits, it does not
  merely hide.
- **Not the hypervisor.** The same log says `Windows Hypervisor Platform
  accelerator is operational` and `Hypervisor compatibility ... are met` a few
  lines before the abort.
- **Not the AVD's own locks.** Deleting `hardware-qemu.ini.lock` (a directory,
  needs `-Recurse`) and `multiinstance.lock` from
  `C:\Users\<user>\.android\avd\Pixel_8_Pro.avd` clears them, and the very
  next launch aborts the same way and re-creates them.
- **Not the discovery directory.** `%LOCALAPPDATA%\Temp\avd\running` exists and
  is **empty**, so nothing is registered as running.
- **Probably not the GPU**, though the log does carry
  `Critical: Failed to load opengl32sw` → `falling back to system OpenGL` a few
  lines earlier, under `-gpu swiftshader_indirect`. Worth eliminating next by
  trying `-gpu host` and `-gpu guest`.

Two more eliminated on the second attempt, same day:

- **Not stale locks on the OTHER AVDs.** `almaeda28.avd` and `almaeda_aosp.avd`
  were still carrying `hardware-qemu.ini.lock` / `multiinstance.lock` from
  2026-08-20, which looked like the instance count. Removing all five lock
  entries across all three AVDs changed nothing — the very next launch aborted
  identically.
- **Not console-port exhaustion.** `Get-NetTCPConnection` shows **5554–5590
  entirely free** while the abort happens.

Left to try: another AVD (`Pixel_5_API_28`) to tell an AVD-specific fault from a
machine-wide one; `-gpu host` and `-gpu guest`; `-port 5560`; `-read-only`; and
emulator 36.5.11's own `%LOCALAPPDATA%\Temp\AndroidEmulator\` state. Reinstalling
the emulator package from SDK Manager is the blunt fallback.

**Consequence:** the project's accepted QA surface is unavailable. On-device
verification currently needs the owner's Infinix, and a debug install shares
`com.alnujom.app` with the release build he is carrying — it would replace it.
So device walks are queued behind him, not merely behind a boot.

## Why this matters

Without this fix, the emulator looks broken every time — the agent has to rediscover that the QEMU VM is healthy and only the window placement is wrong, then write the SetWindowPos call from scratch. Centralising it here means future sessions can paste the PowerShell snippet and move on within a minute.

## Related

- `project_dart_defines.md` memory — `--dart-define-from-file=.env.json` is mandatory or `Supabase.initialize` is skipped.
- `flutter doctor -v` reports the Android SDK at `F:\mm\sdk`. If that path ever changes, update the canonical launch sequence above.
