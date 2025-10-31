# Testing Guide for MediaMio Phase 1

## Prerequisites

### What You Need
1. **Xcode** installed on your Mac
2. **Apple TV Simulator** (included with Xcode)
3. **Jellyfin Server** running and accessible from your Mac
   - Can be on your local network
   - Can be remote with public URL

### Finding Your Jellyfin Server URL

Your Jellyfin server URL typically looks like:
- Local network: `http://192.168.1.100:8096`
- Domain name: `http://jellyfin.example.com`
- With HTTPS: `https://jellyfin.example.com`
- Custom port: `http://192.168.1.100:9000`

To find your server:
1. Check your Jellyfin server's Dashboard → General
2. Look for "Server address" or "LAN address"
3. Note the IP and port number

## Opening and Running the App

### Step 1: Open the Project
```bash
cd /Users/brandonjensen/code/MediaMio
open MediaMio.xcodeproj
```

### Step 2: Select Target
1. In Xcode, click the scheme selector (top-left, near Play button)
2. Ensure **MediaMio** scheme is selected
3. Click the device selector
4. Choose an **Apple TV** simulator (e.g., "Apple TV 4K (3rd generation)")

### Step 3: Build and Run
- Press **⌘R** or click the **Play** button
- Wait for the build to complete
- The Apple TV Simulator will launch automatically

## Testing the Authentication Flow

### Test 1: First-Time Server Connection

**Steps:**
1. App launches and shows **ServerEntryView**
2. You'll see:
   - MediaMio logo
   - "Server Address" text field
   - "Connect" button

3. Enter your Jellyfin server URL:
   - Example: `http://192.168.1.100:8096`
   - Or: `192.168.1.100:8096` (it will add http:// automatically)

4. Click "Connect" (or press Enter/Return on keyboard)

**Expected Results:**
- ✅ Loading spinner appears with "Connecting to server..."
- ✅ If connection succeeds: LoginView appears
- ❌ If connection fails: Error message shows below text field

**Common Errors:**
- "Unable to connect to server": Check server is running and URL is correct
- "Please enter a valid server URL": Check URL format
- "Network error": Check network connection

### Test 2: Login with Credentials

**Steps:**
1. After successful server connection, LoginView appears
2. You'll see:
   - Server name and URL at top
   - Username field
   - Password field
   - "Remember Me" toggle (default: ON)
   - "Sign In" button
   - "Back" button

3. Enter your Jellyfin credentials:
   - Username: Your Jellyfin username
   - Password: Your Jellyfin password

4. Click "Sign In"

**Expected Results:**
- ✅ Loading spinner appears with "Signing in..."
- ✅ If login succeeds: HomeView appears with welcome message
- ❌ If login fails: Error message shows

**Common Errors:**
- "Invalid username or password": Check credentials
- "Authentication failed": Verify user exists on server

### Test 3: Sign Out

**Steps:**
1. From the HomeView (after successful login)
2. You'll see:
   - Success checkmark
   - "Welcome, [username]"
   - Server URL
   - "Sign Out" button (red)

3. Click "Sign Out"

**Expected Results:**
- ✅ Returns to ServerEntryView
- ✅ Credentials are cleared
- ✅ Server URL field is empty (or shows last used URL for convenience)

### Test 4: Remember Me (Auto-Login)

**Steps:**
1. Login with "Remember Me" enabled (default)
2. Once on HomeView, **quit the simulator**:
   - Simulator → Quit Simulator (⌘Q)
3. Run the app again from Xcode (⌘R)

**Expected Results:**
- ✅ App launches directly to HomeView
- ✅ No login required
- ✅ Your session is restored

**To verify:**
- You should see your username on the home screen
- Server URL should be displayed

### Test 5: Remember Me Disabled

**Steps:**
1. Sign out if logged in
2. Login again, but **toggle off "Remember Me"**
3. Complete login to HomeView
4. Quit simulator and relaunch app

**Expected Results:**
- ✅ App shows ServerEntryView (not HomeView)
- ✅ Must login again

## Using the Siri Remote Simulator

### Navigation Controls
The Apple TV simulator provides Siri Remote controls:

**Option 1: On-Screen Remote**
- Simulator → I/O → Show Remote
- Use mouse to click/drag on the remote

**Option 2: Keyboard Shortcuts**
- **Arrow Keys**: Navigate focus (Up/Down/Left/Right)
- **Return/Enter**: Select focused item
- **Escape**: Menu/Back button
- **Space**: Play/Pause (for video playback in future phases)

### Testing Focus Navigation

**What to Test:**
1. Navigate between text fields using Tab or Arrow keys
2. Notice the focus effect:
   - Focused buttons should scale up slightly
   - Shadow appears around focused elements
   - Smooth animation on focus change

3. Try navigating through:
   - Server URL field → Connect button
   - Username → Password → Remember Me → Sign In → Back

**Expected Behavior:**
- ✅ Focus highlights are clear and visible
- ✅ Smooth animations when focus changes
- ✅ Can navigate to all interactive elements
- ✅ Return/Enter activates focused button

## Common Testing Scenarios

### Scenario 1: Invalid Server URL
```
Test: http://invalid-server:8096
Expected: "Unable to connect to server" error
```

### Scenario 2: Wrong Password
```
Test: Correct username, wrong password
Expected: "Invalid username or password" error
```

### Scenario 3: URL Auto-Normalization
```
Test Input: 192.168.1.100:8096 (no http://)
Expected: Converted to http://192.168.1.100:8096
```

### Scenario 4: Trailing Slash Removal
```
Test Input: http://192.168.1.100:8096/
Expected: Converted to http://192.168.1.100:8096
```

## Debugging Tips

### Enable Network Logging
The app already prints some debug info. To see it:
1. Run the app from Xcode
2. Open the **Console** (View → Debug Area → Show Debug Area)
3. Look for network errors and API responses

### Check Keychain
To verify credentials are saved:
1. On macOS, open **Keychain Access** app
2. Search for "mediamio"
3. You should see entries with your saved credentials
   - Note: Simulator uses a separate keychain from your Mac

### Common Issues

**Issue: App won't build**
- Solution: Make sure all new files are added to the MediaMio target
- In Xcode, select each .swift file and check the Target Membership on the right

**Issue: Simulator not showing**
- Solution: Simulator → Device → Apple TV 4K
- Or restart Xcode

**Issue: Focus effects not working**
- Solution: Focus effects only work in the simulator or on real Apple TV
- They won't show in SwiftUI previews

**Issue: Can't type in text fields**
- Solution: Click on the simulator window first to focus it
- Use hardware keyboard (Command+K to toggle software keyboard)

## Success Checklist

Before moving to Phase 2, verify:

- [ ] Server connection works with valid URL
- [ ] Server connection fails gracefully with invalid URL
- [ ] Login works with correct credentials
- [ ] Login fails gracefully with wrong credentials
- [ ] Remember Me saves credentials (auto-login on relaunch)
- [ ] Remember Me disabled doesn't save credentials
- [ ] Sign out clears session and returns to server entry
- [ ] Focus navigation works smoothly with keyboard/remote
- [ ] All buttons have proper focus effects
- [ ] Error messages are clear and helpful
- [ ] Loading states show during network operations
- [ ] App doesn't crash under any scenario

## Next Steps

Once Phase 1 testing is complete:
1. ✅ Verify all checklist items above
2. 📝 Note any issues or improvements needed
3. 🚀 Ready to start Phase 2: Content Loading

### Phase 2 Preview
Next we'll implement:
- Media library browsing
- Movie/TV show lists
- Content detail pages
- Image loading and caching
- Horizontal scrolling rows

## Getting Help

### If Something Doesn't Work

**Check these first:**
1. Is your Jellyfin server running?
2. Can you access it from a web browser on your Mac?
3. Are you on the same network as your server?
4. Is the URL exactly correct (including port)?

**Try this:**
1. Open a web browser
2. Go to your server URL (e.g., `http://192.168.1.100:8096`)
3. If the Jellyfin web interface loads, your URL is correct
4. Use that exact URL in the app

**Still having issues?**
- Check the Xcode console for detailed error messages
- Verify your Jellyfin credentials work in the web interface
- Try a different simulator model
- Restart Xcode and the simulator

## Server Requirements

### Minimum Jellyfin Version
- **Jellyfin 10.7.0** or higher
- Tested with **Jellyfin 10.8.x**

### Required Permissions
- Your Jellyfin user must have:
  - Login permission
  - Media playback permission
  - API access enabled

### Network Requirements
- Server must be accessible from your Mac
- No firewall blocking port 8096 (or your custom port)
- For remote access: Port forwarding configured (if needed)

---

**Happy Testing! 🎉**

Once you've verified everything works, you're ready to move on to building the actual content browsing and playback features in Phase 2!
