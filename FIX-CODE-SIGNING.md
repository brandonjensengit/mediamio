# Fix Code Signing for Simulator Development

You're seeing code signing errors because Xcode is trying to create provisioning profiles. For **simulator-only development**, we don't need real code signing.

## Quick Fix (Option 1): Use "Sign to Run Locally"

### Steps in Xcode:

1. **Open the project**
   ```bash
   open MediaMio.xcodeproj
   ```

2. **Select the project in the navigator**
   - Click on "MediaMio" at the very top of the file list (blue icon)

3. **Select the MediaMio target**
   - In the main editor, under "TARGETS", click "MediaMio"

4. **Go to Signing & Capabilities tab**
   - Click the "Signing & Capabilities" tab at the top

5. **Change the Team**
   - Uncheck "Automatically manage signing" temporarily
   - Then re-check it
   - In the "Team" dropdown, select "None" or your personal team

6. **For Simulator Only: Disable Signing**
   - Click on the project (not target) "MediaMio"
   - Select "Build Settings" tab
   - Search for "Code Signing"
   - Find "Code Signing Identity"
   - For "Debug" configuration, set it to "Sign to Run Locally"

## Quick Fix (Option 2): Change Bundle Identifier

If you want proper code signing later, use a unique bundle ID:

1. In "Signing & Capabilities" tab
2. Change Bundle Identifier from:
   - `Brans.app.MediaMio`

   To something unique:
   - `com.yourname.MediaMio`
   - `dev.yourname.MediaMio`
   - `test.mediamio.app`

3. Make sure "Automatically manage signing" is checked
4. Select your Team from the dropdown

## Quick Fix (Option 3): Command Line

If you prefer command line, I can modify the project settings for you:

Just let me know and I'll update the project file to:
- Set code signing to "Sign to Run Locally" for Debug builds
- Or change the bundle identifier to something that won't conflict

## For Now: Use Simulator

**Important**: These errors only affect:
- Building for real Apple TV hardware
- Creating App Store builds
- Archiving the app

**They do NOT affect**:
- ✅ Running in the Simulator (which is what we want now)
- ✅ Development and testing
- ✅ All of Phase 1-5 development

## Recommended: Option 2

The cleanest solution is:

1. Open Xcode
2. Select MediaMio target
3. Signing & Capabilities tab
4. Change bundle ID to: `com.yourname.mediamio` (use your actual name)
5. Select your personal team
6. Let Xcode handle the rest

This will work for both simulator AND real devices later.

## Verify It Works

After making changes:
1. Select scheme: **MediaMio**
2. Select destination: **Apple TV** (any simulator)
3. Press **⌘R** to build and run
4. App should launch in simulator

## If You Still Get Errors

Try these in order:

### 1. Clean Build Folder
- Xcode → Product → Clean Build Folder (⇧⌘K)
- Then build again (⌘B)

### 2. Delete Derived Data
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/MediaMio-*
```
Then build again in Xcode

### 3. Restart Xcode
- Quit Xcode completely
- Reopen the project
- Try building again

### 4. Check Simulator Destination
- Make sure you selected an **Apple TV Simulator**
- Not "Any tvOS Device" or a physical device
- Click the device selector next to the scheme
- Choose: Apple TV 4K (3rd generation) or similar

## What I Can Do

Would you like me to:

**Option A**: Update the bundle identifier to `com.mediamio.tvos` in the project file?

**Option B**: Set code signing to "Sign to Run Locally" for Debug builds?

**Option C**: You'll fix it manually in Xcode (just follow Option 2 above)?

Let me know and I can make the changes automatically!

## Why This Happens

- Xcode created the project with bundle ID: `Brans.app.MediaMio`
- Your developer account team: `MW25D9KU2A`
- This combination needs a provisioning profile
- For simulator development, we don't actually need this
- Changing the bundle ID or signing method will fix it

---

**Recommended**: Just change the bundle identifier in Xcode to something unique and let Xcode manage the signing automatically. This is the cleanest solution that will work for both simulator and device builds.
