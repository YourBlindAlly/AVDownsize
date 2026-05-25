# AVDownsize

Right-click any video file in Windows File Explorer to compress and downsize it automatically using FFmpeg. Inspired by SonicAxiom's AVConvert.

## What it does

AVDownsize analyzes your video file and re-encodes it to H.265 (HEVC), which typically cuts file size by 40 to 60 percent with no visible quality loss. You choose a compression level from a small submenu, and the result lands in the same folder with a new file name. The original is left untouched unless you turn on the delete option in Settings.

## Requirements

FFmpeg must be installed and available on your system PATH. If you can open a command prompt and type ffmpeg and get a response, you are good. If not, download FFmpeg from ffmpeg.org and follow their Windows installation instructions.

## Installation

1. Download or clone this repository to any folder on your computer. The folder can stay wherever you put it, so choose a permanent home before installing.

2. Double-click Install.bat. A brief console window will appear and then close automatically.

3. That is it. Right-click any video file in File Explorer and look for AVDownsize in the context menu.

To remove AVDownsize, double-click Uninstall.bat.

## Menu options

Auto Compress (Recommended): Analyzes the source codec and picks the best balance of quality and size. Most videos will shrink by 40 to 60 percent. If the video is already H.265, it applies a lighter compression pass.

Compress Smaller: More aggressive compression. Larger size reduction, slight quality trade-off. Good for archiving or sharing where size matters more.

Compress High Quality: Conservative compression. Smaller size reduction but the output is visually very close to the original. Good when quality is the priority.

To change settings, run settings.ps1 directly from the AVDownsize folder by right-clicking it and choosing Run with PowerShell. Settings include the FFmpeg path, output folder, output file suffix, 4K downscaling, and automatic deletion of the original file.

## Output files

By default, compressed files are saved in the same folder as the original with _compressed added to the file name. For example, holiday.mp4 becomes holiday_compressed.mp4. You can change the suffix or choose a different output folder in Settings.

## Batch processing

Select multiple video files in File Explorer, right-click, and choose a compression option. Windows will process each file in sequence.

## Uninstalling

Right-click uninstall.ps1 and choose Run with PowerShell. This removes the context menu entries. Your settings file in AppData is preserved unless you delete it manually.

## Notes

Output files are always MP4 with H.265 video and AAC audio. The hvc1 tag is included for compatibility with Apple devices. The original file is never deleted unless you enable that option in Settings.

## License

MIT
