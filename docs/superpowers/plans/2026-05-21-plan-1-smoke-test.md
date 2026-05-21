# Plan 1 Smoke Test — Checklist

Run after each significant change to the record/session/library/settings
flow on macOS.

- [ ] App launches into the record screen with the new theme.
- [ ] Source pill opens the popover; selection persists across relaunch.
- [ ] Record → active state morphs button color, timer, waveform.
- [ ] Stop pushes session view with transcribing placeholder.
- [ ] Title auto-fills from transcript and is editable.
- [ ] Copy text snackbar appears; clipboard contains text.
- [ ] Export writes a .txt file next to the .wav.
- [ ] Library lists today's recording and re-opens it without re-transcribing.
- [ ] Settings → Advanced edits persist; clearing them re-enables auto-detect.
- [ ] Renaming the ffmpeg binary surfaces the warm error banner.
