# Bug: Unnecessary transcode on supported MKV + HEVC content

**Filed:** 2026-04-22
**Fixed:** 2026-04-22
**Severity:** P1 — user-visible, every MKV movie in the library hits it
**Status:** Fixed (code) · Needs manual re-verification on hardware

## Summary

The app transcoded 4K HEVC MKV files to H.264 1080p even though Apple TV
hardware can Remux them natively. This added ~10 seconds of server
warmup to every playback start and caused A/V sync issues during testing.

## Actual root cause

Not what the original investigation plan guessed. The codec decision
tree in `AppleTVCodecSupport.getBestPlaybackMode(for:)` was returning
`.remux` correctly. `PlaybackStreamURLBuilder.buildRemuxURL()` was NOT
returning nil. The problem was upstream of both.

`SettingsManager.swift:16` (and the twin on line 128 in `resetToDefaults()`)
defaulted `streamingMode` to `StreamingMode.transcode` with the comment
*"Force transcode to fix video decoder error -12900"*. That came from
commit `1dd695a` (2025-11-10), which was a blanket workaround for
`kVTVideoDecoderBadDataErr` on some Direct Play content.

With `streamingMode == .transcode`, `PlaybackStreamURLBuilder.build()`
falls through to the `default` branch of its `switch streamingMode` at
`PlaybackStreamURLBuilder.swift:75-80` and calls `buildTranscodeURL()`
directly — the whole `buildAuto` cascade (Direct Play → Direct Stream →
Remux → Transcode) never executes. That's why the logs showed the
codec analysis ("Container Supported: ❌") run and produce the correct
answer, and then the app ignored it.

## Fix

1. `SettingsManager.swift:16` — default `streamingMode` flipped from
   `StreamingMode.transcode.rawValue` to `StreamingMode.auto.rawValue`.
2. `SettingsManager.swift:128` — same change in `resetToDefaults()` so
   "Reset to defaults" does the right thing.
3. `PlaybackStreamURLBuilderTests.swift` — added regression test
   `remux_hevc_ac3_mkv_copiesStreamsWithoutVideoBitrate()`. Asserts that
   HEVC + AC-3 in MKV under `.auto` mode produces a Remux URL with
   `VideoCodec=copy`, no `VideoBitrate`, no `MaxWidth`/`MaxHeight`.

The original `-12900` concern is now covered by
`PlaybackFailoverController` (see `PlaybackFailoverController.swift:17-18`):
if the decoder actually chokes on a stream, the controller observes
`playerItem.status == .failed` or `failedToPlayToEndTime` and downgrades
to Transcode at runtime. That's a much better safety net than forcing
every stream through transcode preemptively.

## Remaining manual verification

Default value changes only affect fresh installs and
"Reset to Defaults". A dev sim that was running before this fix will
have `"streamingMode"` persisted as `"Transcode"` in `UserDefaults`.

To re-verify:

1. Wipe the sim's app data (or go to **Settings → Streaming → Mode → Auto**
   in-app) so `streamingMode` reads `.auto`.
2. Play the same Fantastic Four test file.
3. Confirm the log sequence is `📊 REMUX - Need container change only`
   → `📦 Using Remux - container change only (MKV→MP4)` → NOT
   `⚠️ Using transcoding`.
4. Slide down on the Siri Remote to open Playback Info. Confirm
   `Play Method: Remux`.
5. Confirm playback starts faster (should be ~2-4s instead of ~10+s).
6. Watch for decoder errors. If `-12900` returns, the failover
   controller should demote to Transcode on its own — watch for
   `🛡️ Failover` log lines.

## Reproduction (original)

1. Point the sim at any Jellyfin server with an MKV-packaged HEVC movie
2. Play the movie
3. Slide down the Siri Remote surface to open the Playback Info panel
4. Observe `Play Method: Transcode` instead of `Remux`

## Evidence from the original session

```
🎥 Video stream: codec=hevc, 3840x1600
Container Supported: ❌
⚠️ Using transcoding - quality may be reduced
🎬 Transcode URL: .../master.m3u8?VideoCodec=h264&MaxWidth=1920&MaxHeight=1080&VideoBitrate=15000000…
🎬 LOADING VIDEO — … (Transcode)
```

"Container Supported: ❌" comes from `getBestPlaybackMode` — confirming
the tree ran. The subsequent "⚠️ Using transcoding" is `buildTranscodeURL`'s
first print. The telltale missing print was
`📦 Using Remux - container change only (MKV→MP4)`: if the cascade had
entered `.remux` and then failed, we would have seen it, followed by
`⚠️ Remux failed, falling back to transcode`. Neither appeared, which
is what pointed to the switch short-circuiting on mode.

## Expected impact (unchanged from original)

- ~10 sec faster playback start on every MKV movie
- Eliminates A/V sync drift from transcoded HLS on the sim's desktop
  audio stack
- Drops server CPU from ~80-100% to ~10-20% during playback
- Preserves HDR / DV on files where the server has it but transcode
  would strip it

## Related / adjacent pre-existing issues (out of scope)

Noted in the original ticket; none of these are addressed here:

- `HomeView.HeroBanner` prints `📊 hasProgress=…` on every SwiftUI
  re-render (thousands of lines/sec).
- Same HeroBanner divides by zero when `total=0`, logs `progress=nan%`.
- `VideoPlayerView` unmounts → remounts on first open, causing a
  cancelled HEAD (`Code=-999`). Survivable; ~300ms cost.
- `SubtitleTrackManager` logs `⚠️ Subtitle mode is OFF, but enabling
  first track anyway` — auto-enable ignores the user's "off" preference.
