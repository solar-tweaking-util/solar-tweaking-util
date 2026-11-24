# Solar Tweaking Util

Independent PowerShell 5.1 + WPF Windows 11 utility with a dark purple interface.

## Run
Open Windows PowerShell as Administrator:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
irm "https://raw.githubusercontent.com/solar-tweaking-util/solar-tweaking-util/main/solar.ps1" | iex
```

## Initial features
- WPF interface: Tweaks, Config, Updates, Gaming and Log tabs
- Standard, Minimal, Advanced, Clear and Select All presets
- Selectable actions, confirmation prompts and logs
- Backups for supported registry preferences, service startup state and active power plan
- Optional Xbox consumer-app removal while preserving Microsoft Store and Gaming Services

## Limitations
This is an initial Solar implementation, not a complete WinUtil port. AppX removals, temporary-file cleanup and hibernation changes are not fully reversible through registry restore. Make a Windows restore point or full backup before major changes. Tweaks do not guarantee FPS gains. Solar does not overclock, change voltage, or disable thermal protections, Defender, Bluetooth, Windows Update or essential drivers.

Solar Tweaking Util is independent and is not affiliated with Chris Titus Tech.
