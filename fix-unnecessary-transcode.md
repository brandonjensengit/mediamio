# Bug: Unnecessary transcode on supported MKV + HEVC content

**Filed:** 2026-04-22
**Severity:** P1 — user-visible, every MKV movie in the library likely hits it
**Status:** Open

## Summary

The app transcodes 4K HEVC MKV files to H.264 1080p even though Apple TV
hardware can Direct-Play (or at least Remux) them natively. This adds
~10 seconds of server warmup to every playback start and causes the
A/V sync issues reported during testing.

## Evidence from the session

Confirmed in live stdout logs while watching *Marvel Studios' The Fantastic
Four: First Steps — World Premiere*:

```
🎥 Video stream: codec=hevc, 3840x1600
Container Supported: ❌
⚠️ Using transcoding - quality may be reduced
🎬 Transcode URL: .../master.m3u8?VideoCodec=h264&MaxWidth=1920&MaxHeight=1080&VideoBitrate=15000000…
🎬 LOADING VIDEO — … (Transcode)
```

So:
- Source: HEVC 3840×1600 in MKV
- Apple TV (4K) natively decodes HEVC up to 2160p, including in MKV via remux
- App still chose `.transcode` — re-encoded to H.264 1080p at 15 Mbps

## Root cause hypothesis

The codec decision tree itself is *correct* on paper:

`MediaMio/Utilities/AppleTVCodecSupport.swift:104-116` returns `.remux`
when video + audio are supported but the container isn't. HEVC is in
`supportedVideoCodecs`, AC-3/E-AC-3 are in `supportedAudioCodecs`, and
MKV is **not** in `supportedContainers` (which only has
`mp4 / m4v / mov / ts / m2ts`). So the tree should say `.remux`.

The downgrade to `.transcode` therefore has to happen inside
`PlaybackStreamURLBuilder.buildAuto(...)`
(`MediaMio/Services/Playback/PlaybackStreamURLBuilder.swift:86-118`).
The switch falls through to `.transcode` whenever the mode-specific URL
builder returns nil:

```swift
case .remux:
    if let url = buildRemuxURL() { return Result(url: url, mode: .remux) }
    print("⚠️ Remux failed, falling back to transcode")
    fallthrough
case .transcode: …
```

So `buildRemuxURL()` is returning nil (or its equivalent for
`.directStream` if audio went through that path). The investigation
starts there.

Secondary possibility: the tree is right, the URL builder succeeded,
and the failover controller downgraded to transcode at runtime. Less
likely because the log shows `🎬 LOADING VIDEO — ... (Transcode)` on
the *first* attempt, not after a failover event.

## Reproduction

1. Point the sim at any Jellyfin server with an MKV-packaged HEVC movie
   (i.e. essentially any movie ripped from a disc)
2. Play the movie
3. Slide down the Siri Remote surface to open the Playback Info panel
4. Observe `Play Method: Transcode` instead of `Remux` or `Direct Play`

## Investigation plan (for next session)

1. **Narrow down which builder returned nil.** Add a `print` at the top
   of `buildRemuxURL` / `buildDirectStreamURL` / `buildDirectPlayURL`
   that logs each required field as it's resolved. The real reason for
   the nil return is probably one specific missing field. Most likely
   culprit: `PlaybackStreamURLBuilder` computes the playback URL using
   `MediaSourceId` + container-aware endpoint paths, and may be
   returning nil when the source container isn't in the supported list
   — essentially the same "MKV is bad" mistake recurring at the URL
   layer.

2. **Confirm the path in `buildRemuxURL`.** File:
   `MediaMio/Services/Playback/PlaybackStreamURLBuilder.swift`. Look for
   the same `isContainerSupported` check or a hardcoded container
   whitelist. If one exists there, the fix is the same as in the codec
   support utility — let MKV through when the underlying codecs are OK.

3. **Verify fix paths for the tree:**
   - Direct Play: HEVC + AC-3 + MKV → currently would fall to `.remux`
     (correct; MKV isn't a Direct-Play container on AVFoundation — it
     has to be mux-wrapped first).
   - Remux: HEVC + AC-3 + MKV → should emit `.remux` URL and serve a
     lightweight stream (container swap only, server CPU ~10-20%).
   - Direct Stream: HEVC + DTS/TrueHD + MKV → audio transcode, video
     pass-through.
   - Transcode: only when video codec is unsupported (VP9, AV1 on
     pre-A12 Apple TVs) OR bitrate exceeds device cap.

4. **Add a test.** `PlaybackStreamURLBuilderTests` already covers codec
   decisions. Add a case: HEVC + AC-3 + MKV should produce a remux URL,
   not a transcode URL. Steal a fixture from the existing test helper.

5. **Verify manually.** Re-run the same Fantastic Four file post-fix:
   Playback Info should say `Play Method: Remux`, and the transcode
   URL query (`VideoCodec=h264&MaxWidth=1920…`) should be gone —
   should now be a direct .mkv or /stream.mp4 remux endpoint.

## Expected impact

- ~10 sec faster playback start on every MKV movie
- Eliminates the A/V sync issue reported during sim testing (transcoded
  HLS on the sim's desktop audio stack is where the sync drift came from)
- Drops server CPU from ~80-100% to ~10-20% during playback — meaningful
  on a Raspberry-Pi-class server
- Preserves HDR / DV on the rare files where the server happens to have
  it but the current transcode strips it

## Related / adjacent pre-existing issues noticed this session

Not part of this ticket's scope — flagged so they don't get lost:

- `HomeView.HeroBanner` prints `📊 hasProgress=…` on every SwiftUI
  re-render, producing thousands of log lines per second while the
  banner is on screen. Pre-existing logging spam; not functional.
- Same HeroBanner divides by zero when an item has `total=0`, giving
  `progress=nan%` in the log. Cosmetic.
- `VideoPlayerView` briefly unmounts → remounts on first open, causing
  a cancelled HEAD (`Code=-999`). The `isLoadingVideo` guard in the VM
  (`⚠️ Video already loading, skipping duplicate request`) swallows the
  duplicate, so it's survivable, but the remount wastes ~300ms.
- `SubtitleTrackManager` logs `⚠️ Subtitle mode is OFF, but enabling
  first track anyway` — auto-enable ignores the user's "off" preference.

## Resume checklist for the next session

1. Open this file
2. Read `PlaybackStreamURLBuilder.buildRemuxURL` — look for a
   container-compatibility gate that short-circuits MKV
3. Read `buildDirectStreamURL` for the same
4. Run `grep -rn "remux\|container" MediaMio/Services/Playback/`
5. Follow the "Investigation plan" above — expected 1-2 hour fix
