# AVDownsize — Claude Handoff Notes

## What this project is

AVDownsize is a Windows File Explorer right-click context menu tool that compresses video files using FFmpeg and H.265 encoding. It was built for Rusty Perez, a screen reader user, so accessibility is a primary concern in all UI decisions. Inspired by SonicAxiom's AVConvert but focused specifically on video downsizing.

## How it works

The user right-clicks a video file in File Explorer and selects AVDownsize. A small WinForms dialog appears with three radio button choices: Auto Compress, Compress Smaller, and Compress High Quality. After pressing OK the dialog closes, FFmpeg runs in the background, and a summary MessageBox appears when done showing original size, compressed size, percentage reduction, and encoder used.

## File structure

chooser.ps1 — WinForms dialog presenting three compression options. Launched by the registry context menu entry. Hides its console window via Windows API (GetConsoleWindow/ShowWindow). On OK spawns compress.ps1 as a separate process.

compress.ps1 — Main compression engine. Accepts -InputFile and -Mode parameters. Hides its own console window via Windows API. Probes video with ffprobe, auto-detects hardware encoders, falls back to software libx265. Uses call operator with splatting (& ffmpeg @args) to correctly handle file paths with spaces. Shows completion MessageBox with size stats and encoder name.

settings.ps1 — WinForms settings dialog. Not accessible from the chooser. Run directly by right-clicking and choosing Run with PowerShell. Saves to %APPDATA%\AVDownsize\settings.json.

setup.ps1 — Registers the context menu in HKCU (no admin required). Runs Unblock-File on all scripts to remove the downloaded-from-internet security mark. Registers under SystemFileAssociations for video and specific extensions: .mp4 .mov .avi .mkv .wmv .m4v .flv .webm .mpg .mpeg .ts .mts .m2ts .3gp.

uninstall.ps1 — Removes all AVDownsize registry entries. Preserves settings in %APPDATA%.

Install.bat — Double-click to install.

Uninstall.bat — Double-click to uninstall.

## Settings (stored in %APPDATA%\AVDownsize\settings.json)

ffmpegPath — path to ffmpeg executable, default "ffmpeg" (assumes on PATH)
ffprobePath — path to ffprobe executable, default "ffprobe"
outputFolder — where to save compressed files, default "" (same folder as source)
deleteOriginal — delete source file after compression, default false
outputSuffix — appended to filename before .mp4 extension, default "_compressed"
downscale4K — downscale 4K video to 1080p in auto and smaller modes, default true
showSummary — show the completion MessageBox, default true

## Compression modes

Auto: CRF 26 for H.264 source, CRF 28 if already H.265. Good balance.
Smaller: CRF 32. More aggressive, good for archiving.
High Quality: CRF 22. Conservative, visually near-lossless. Does not downscale 4K.

All modes encode to H.265 (HEVC), output as .mp4 with -tag:v hvc1 for Apple compatibility. FFmpeg is called with the & operator and array splatting to handle paths with spaces correctly.

## Hardware encoder detection

compress.ps1 tests encoders in this order: hevc_qsv (Intel Quick Sync), hevc_nvenc (NVIDIA), hevc_amf (AMD), then libx265 software fallback. The test does a real 1-second encode to a temp mp4 file to catch encoders that pass a trivial test but fail on real content.

On Rusty's machine (HP EliteDesk 800, Intel integrated graphics, Windows 10 22H2, FFmpeg 8.8.1) all hardware encoders fail the test. The tool uses libx265 with the "fast" preset. Intel Driver and Support Assistant found no outdated drivers, so the Intel Media SDK runtime for QSV may simply not be present on this system.

## Two remaining UI issues — top priority for next session

These are the main things to fix when work resumes. Both have been worked on extensively. A fresh perspective is needed.

Issue 1: Blank PowerShell console window appears and stays visible throughout compression. It goes away only after the user clicks OK on the completion dialog.
Tried and failed:
  -WindowStyle Hidden alone — window still appears
  Windows API GetConsoleWindow/ShowWindow — did not hide window
  VBScript launcher via wscript.exe — blocked by group policy on this HP EliteDesk 800 business PC
  FreeConsole() via Windows API — broke the WinForms dialog entirely, nothing appeared at all
Untried: compiling a small C# or Go wrapper exe that uses the Windows subsystem (no console by design) to launch PowerShell. This is the most promising remaining option.

Issue 2: Completion notification does not appear in front of other windows. User has to alt-tab through the full stack of open windows to find it.
Tried and failed:
  MessageBox with DefaultDesktopOnly option — appeared but did not take focus
  WinForms form with TopMost=true — appeared but did not take focus either
Current state: compress.ps1 uses a TopMost WinForms form for the completion notice (this replaced the MessageBox). TopMost makes the window appear above others visually once found, but it still does not steal focus from whatever the user is currently doing.
Untried: calling SetForegroundWindow() and BringWindowToTop() via Windows API on the form's handle after showing it. Also worth trying: using the form's Activate() method combined with setting it as the foreground window before ShowDialog(). The restriction on focus stealing in Windows (introduced in Windows 2000) may require calling AllowSetForegroundWindow() first.

## Other known issues and future ideas

Settings are not accessible from the chooser dialog. Run settings.ps1 directly.

The Windows Shell cascading submenu (SubCommands registry approach) was attempted twice and never worked reliably with the screen reader. The current WinForms chooser dialog is better for accessibility anyway.

Batch selection spawns one process per file simultaneously. Could cause high CPU load on large batches.

Future ideas discussed but not implemented: start notification so user knows compression is running, context menu entry for Settings, compression log file.

## User notes

Rusty is a screen reader user (Windows 10, NVDA or similar). All UI must be accessible. No markdown symbols or bullet points in responses — plain text only. WinForms dialogs are preferred over console output for all user-facing messages.

FFmpeg version 8.8.1 is installed on Rusty's machine and on the system PATH. ffprobe is also available.

## Repository

https://github.com/YourBlindAlly/AVDownsize
