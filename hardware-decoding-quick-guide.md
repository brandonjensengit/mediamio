# Quick Guide: Client-Side Hardware Decoding

## TL;DR

**Current:** Server transcodes video → CPU intensive, quality loss
**Better:** Apple TV decodes video → Fast, maximum quality

Apple TV can decode H.264, HEVC, VP9 natively with its hardware!

## Copy to Claude Code

```
Enable client-side hardware decoding to offload work from server to Apple TV.

Apple TV has powerful hardware decoders (H.264, HEVC, VP9) that can play most formats without server transcoding.

KEY CONCEPT:
Instead of server re-encoding video, send original video to Apple TV and let its hardware chips decode it.

IMPLEMENTATION:

1. ENABLE DIRECT STREAM (Best Quality)
   Create buildDirectStreamURL():
   
   URLQueryItem(name: "VideoCodec", value: "copy")  ← DON'T touch video!
   URLQueryItem(name: "AudioCodec", value: "aac")   ← Transcode audio only
   URLQueryItem(name: "Container", value: "ts,mp4")
   URLQueryItem(name: "EnableAutoStreamCopy", value: "true")
   
   Result: Original video + compatible audio

2. DETECT SUPPORTED CODECS
   Create AppleTVCodecSupport class:
   
   supportedVideoCodecs = ["h264", "avc", "hevc", "h265", "vp9"]
   supportedAudioCodecs = ["aac", "mp3", "ac3", "eac3", "flac", "alac"]
   
   func canPlayNatively(item) -> Bool {
       // Check if video/audio codecs are in supported list
   }

3. SMART MODE SELECTION
   Choose best streaming mode:
   
   if video_codec_supported && audio_codec_supported {
       return DirectPlay  // Everything works natively
   } else if video_codec_supported {
       return DirectStream  // Video native, transcode audio only
   } else {
       return Transcode  // Need to transcode video
   }

4. REMUX FOR MKV FILES
   For MKV containers, just change to MP4:
   
   URLQueryItem(name: "VideoCodec", value: "copy")
   URLQueryItem(name: "AudioCodec", value: "copy")
   URLQueryItem(name: "Container", value: "mp4")
   
   This is FAST - no re-encoding, just container change

STREAMING MODES:

1. Direct Play (Best)
   - Original file → Apple TV hardware decodes
   - Server CPU: 0%
   - Quality: Maximum
   
2. Direct Stream (Excellent)
   - Original video + transcoded audio → Apple TV decodes video
   - Server CPU: 5-10%
   - Quality: Maximum video

3. Remux (Very Good)
   - Change container only (MKV→MP4)
   - Server CPU: 10-20%
   - Quality: Maximum

4. Transcode (Fallback)
   - Re-encode everything
   - Server CPU: 80-100%
   - Quality: Reduced

WHAT APPLE TV CAN DECODE:

Video: ✅ H.264, ✅ HEVC/H.265, ✅ VP9
Audio: ✅ AAC, ✅ MP3, ✅ AC3, ✅ E-AC3, ✅ FLAC, ✅ ALAC
Containers: ✅ MP4, ✅ MOV, ✅ TS, ⚠️ MKV (remux to MP4)

TESTING:
1. H.264 MP4 file:
   - Should use Direct Play ✅
   - Check server CPU: <5% ✅
   
2. HEVC MKV file:
   - Should use Direct Stream or Remux ✅
   - Check server CPU: <20% ✅
   
3. Quality check:
   - Video should be crystal clear ✅
   - No compression artifacts ✅

Read client-side-hardware-decoding.md for complete implementation.
```

---

## The Magic Parameter

### Server Transcoding (Current):
```swift
URLQueryItem(name: "VideoCodec", value: "h264")
```
❌ Server re-encodes video

### Hardware Decoding (Better):
```swift
URLQueryItem(name: "VideoCodec", value: "copy")
```
✅ Apple TV decodes with hardware

**That's it!** This one change can save massive server CPU.

---

## Quick Implementation

### Step 1: Direct Stream URL (2 minutes)

```swift
func buildDirectStreamURL(for item: MediaItem) -> URL {
    var components = URLComponents(string: "\(serverURL)/Videos/\(item.id)/stream")!
    
    components.queryItems = [
        URLQueryItem(name: "api_key", value: apiKey),
        URLQueryItem(name: "VideoCodec", value: "copy"),      // ← Magic!
        URLQueryItem(name: "AudioCodec", value: "aac"),
        URLQueryItem(name: "Container", value: "ts,mp4"),
        URLQueryItem(name: "EnableAutoStreamCopy", value: "true"),
    ]
    
    return components.url!
}
```

### Step 2: Detect Support (3 minutes)

```swift
func canUseHardwareDecoding(item: MediaItem) -> Bool {
    let videoCodec = item.mediaStreams?.first(where: { $0.type == "Video" })?.codec?.lowercased()
    
    let supported = ["h264", "avc", "hevc", "h265", "vp9"]
    
    return supported.contains(videoCodec ?? "")
}
```

### Step 3: Smart Selection (2 minutes)

```swift
func buildStreamURL(for item: MediaItem) -> URL {
    if canUseHardwareDecoding(item: item) {
        print("✅ Using hardware decoding")
        return buildDirectStreamURL(for: item)
    } else {
        print("⚠️ Need to transcode")
        return buildTranscodeURL(for: item)
    }
}
```

---

## Streaming Modes Explained

### 1. Direct Play
```
Server: Sends original file
Apple TV: Hardware decodes everything
Result: 💯 Perfect quality, 0% server CPU
```

### 2. Direct Stream (Recommended)
```
Server: Sends original video + AAC audio
Apple TV: Hardware decodes video
Result: ✅ Perfect video, compatible audio, 5-10% server CPU
```

### 3. Remux
```
Server: Changes MKV → MP4 (no re-encoding)
Apple TV: Hardware decodes
Result: ✅ Perfect quality, 10-20% server CPU
```

### 4. Transcode
```
Server: Re-encodes everything
Apple TV: Plays pre-encoded stream
Result: ⚠️ Reduced quality, 90% server CPU
```

---

## What Needs Transcoding?

### ✅ Apple TV Can Decode (Use Hardware):
```
Video: H.264 ✅  HEVC ✅  VP9 ✅
Audio: AAC ✅  MP3 ✅  AC3 ✅  E-AC3 ✅  FLAC ✅
```

### ⚠️ Needs Remux:
```
Container: MKV → Remux to MP4
```

### ❌ Needs Transcoding:
```
Video: MPEG-2, VC-1, AV1 (not yet)
Audio: DTS, TrueHD
```

---

## Performance Comparison

### Before (Server Transcoding):
```
Server CPU:  90% 🔥
Quality:     Reduced ⚠️
Start Time:  10-15 sec
Power:       High
```

### After (Hardware Decoding):
```
Server CPU:  5% ✅
Quality:     Maximum ✅
Start Time:  3-5 sec ✅
Power:       Low ✅
```

---

## Visual Indicator

Show users what's happening:

```swift
struct DecodingModeIndicator: View {
    let mode: String  // "Hardware" or "Transcoding"
    
    var body: some View {
        HStack {
            Image(systemName: mode == "Hardware" ? "cpu.fill" : "server.rack")
            Text(mode == "Hardware" ? "Hardware Decoded" : "Transcoding")
        }
        .padding(8)
        .background(mode == "Hardware" ? Color.green.opacity(0.3) : Color.orange.opacity(0.3))
        .cornerRadius(8)
    }
}
```

---

## Settings

```swift
struct HardwareDecodingSettings: View {
    @AppStorage("useHardwareDecoding") var useHardware = true
    
    var body: some View {
        Form {
            Toggle("Use Hardware Decoding", isOn: $useHardware)
            
            Text("Let Apple TV decode video instead of the server. Much faster and better quality.")
                .font(.caption)
        }
    }
}
```

---

## Testing Checklist

### Test H.264 File:
```
[ ] Uses Direct Play or Direct Stream
[ ] Server CPU < 10%
[ ] Video quality is maximum
[ ] Starts playing quickly
```

### Test HEVC MKV File:
```
[ ] Uses Direct Stream or Remux
[ ] Server CPU < 20%
[ ] Video quality is maximum
[ ] No transcoding delay
```

### Test Unsupported Codec:
```
[ ] Falls back to transcode
[ ] Still plays correctly
[ ] User sees "Transcoding" indicator
```

---

## Common Issues

### Issue 1: Still Transcoding Video
**Check:** Is VideoCodec set to "copy"?
**Fix:** Change to "copy" instead of "h264"

### Issue 2: Audio Not Working
**Cause:** Incompatible audio codec
**Fix:** Set AudioCodec to "aac" to transcode audio only

### Issue 3: MKV Not Playing
**Cause:** Container not supported
**Fix:** Use Remux mode to change MKV → MP4

---

## Key Differences from Android/Google

**What Android/Google devices do:**
- Same thing! They use hardware decoders
- Send original video to device
- Let device's chips decode it

**What you're doing now:**
- Enabling same feature on Apple TV
- Using Apple's VideoToolbox framework
- Leveraging A-series chip's media engine

**Result:** Same fast, high-quality experience!

---

## Summary

**One Simple Change:**
```swift
// Instead of:
"VideoCodec": "h264"  // Server transcodes

// Use:
"VideoCodec": "copy"  // Apple TV decodes
```

**Benefits:**
- ✅ 90% less server CPU
- ✅ Maximum video quality
- ✅ Faster playback
- ✅ Lower latency

**What Apple TV Can Decode:**
- H.264 (most common) ✅
- HEVC/H.265 (4K) ✅
- VP9 (YouTube) ✅
- Most audio formats ✅

**Time to Implement:** 10 minutes
**Impact:** Massive improvement!

This is exactly what Android/Google devices do - offload decoding to the device's hardware! 🚀
