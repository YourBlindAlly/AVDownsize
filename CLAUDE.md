# AVDownsize — Claude Handoff Notes

## What this project is

AVDownsize is a Windows File Explorer right-click context menu tool that compresses video files using FFmpeg and H.265 encoding. It was built for Rusty Perez, a screen reader user, so accessibility is a primary concern in all UI decisions. Inspired by SonicAxiom's AVConvert but focused specifically on video downsizing.

## How it works

The user right-clicks a video file in File Explorer and selects AVDownsize. A small WinForms dialog appears with three radio button choices: Auto Compress, Compress Smaller, and Compress High Quality. After pressing OK the dialog closes, FFmpeg runs silently in the background, and a summary MessageBox pops up on top when done showing original size, compressed size, and percentage reduction.

## File structure

chooser.ps1 — WinForms dialog that presents the three compression options. Launched by the registry context menu entry. On OK it spawns compress.ps1 as a hidden process.

compress.ps1 — Main compression engine. Accepts -InputFile and -Mode parameters. Probes the video with ffprobe, auto-detects hardware encoders (hevc_qsv, hevc_nvenc, hevc_amf, hevc_mf) and falls back to software libx265. Shows a TopMost MessageBox on completion with size stats and encoder name.

settings.ps1 — WinForms settings dialog. Not currently accessible from the chooser. Run it directly by right-clicking and choosing Run with PowerShell. Saves to %APPDATA%\AVDownsize\settings.json.

setup.ps1 — Registers the context menu in HKCU (no admin required). Registers under SystemFileAssociations for the generic video type and for specific extensions: .mp4 .mov .avi .mkv .wmv .m4v .flv .webm .mpg .mpeg .ts .mts .m2ts .3gp. Also creates the default settings.json if it does not exist.

uninstall.ps1 — Removes all AVDownsize registry entries. Preserves the settings file in %APPDATA%.

Install.bat — Double-click to install. Calls setup.ps1 with -ExecutionPolicy Bypass so no policy prompt appears.

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

All modes encode to H.265 (HEVC), output as .mp4 with -tag:v hvc1 for Apple compatibility.

## Hardware encoder detection

compress.ps1 tests encoders in this order: hevc_qsv (Intel Quick Sync), hevc_nvenc (NVIDIA), hevc_amf (AMD), hevc_mf (Windows MediaFoundation), then libx265 software. The test encodes a tiny black frame and checks the exit code.

On Rusty's machine (HP EliteDesk 800, Intel integrated graphics, Windows 10) hevc_qsv is listed by FFmpeg but fails the runtime test — the Intel Media SDK runtime is likely missing or outdated. The tool falls back to libx265 with the "fast" preset. Updating the Intel graphics driver via Intel Driver and Support Assistant may fix this.

## Known issues and things not yet done

Settings are not accessible from the chooser dialog. When launched from chooser.ps1 the settings window was unreliable. For now run settings.ps1 directly from the AVDownsize folder.

A VBScript launcher (launcher.vbs) was attempted to eliminate the brief PowerShell console flash when the menu is activated. Windows blocked it because downloaded files from GitHub get a Zone.Identifier mark. The approach was reverted. The console flash is minor and currently accepted.

The Windows Shell cascading submenu (SubCommands registry approach) was attempted twice and never worked reliably with the screen reader. The current WinForms dialog approach is better for accessibility anyway.

Batch selection: when multiple files are selected and AVDownsize is chosen, Windows calls the command once per file, spawning multiple simultaneous compression processes. For large batches this could cause high CPU load. Not yet addressed.

## User notes

Rusty is a screen reader user. All UI must be accessible. Prefer WinForms dialogs over console output for any user-facing messages. MessageBox calls use a TopMost owner form so they appear in front of other windows. No markdown symbols or bullet points in responses to Rusty — plain text only.

FFmpeg version 8.8.1 is installed on Rusty's machine and on the system PATH.

## Repository

https://github.com/YourBlindAlly/AVDownsize
