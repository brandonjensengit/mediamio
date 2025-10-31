# Authentication Flow Diagram

## User Journey

```
┌─────────────────────────────────────────────────────────────┐
│                      App Launch                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                   ┌──────────────────────┐
                   │ Check Keychain for   │
                   │ Saved Credentials    │
                   └──────────────────────┘
                              │
                ┌─────────────┴─────────────┐
                │                           │
                ▼                           ▼
        ┌──────────────┐           ┌──────────────┐
        │ Credentials  │           │ No Saved     │
        │ Found        │           │ Credentials  │
        └──────────────┘           └──────────────┘
                │                           │
                ▼                           ▼
        ┌──────────────┐           ┌──────────────────┐
        │ Auto-Login   │           │ ServerEntryView  │
        │ to HomeView  │           │                  │
        └──────────────┘           └──────────────────┘
                                            │
                                            ▼
                                   ┌─────────────────┐
                                   │ User Enters     │
                                   │ Server URL      │
                                   └─────────────────┘
                                            │
                                            ▼
                                   ┌─────────────────┐
                                   │ Test Connection │
                                   │ GET /System/Info│
                                   └─────────────────┘
                                            │
                              ┌─────────────┴─────────────┐
                              │                           │
                              ▼                           ▼
                      ┌──────────────┐           ┌──────────────┐
                      │ Connection   │           │ Connection   │
                      │ Failed       │           │ Success      │
                      └──────────────┘           └──────────────┘
                              │                           │
                              ▼                           ▼
                      ┌──────────────┐           ┌──────────────┐
                      │ Show Error   │           │  LoginView   │
                      │ Try Again    │           │              │
                      └──────────────┘           └──────────────┘
                                                          │
                                                          ▼
                                                 ┌─────────────────┐
                                                 │ User Enters     │
                                                 │ Username/Password│
                                                 └─────────────────┘
                                                          │
                                                          ▼
                                                 ┌─────────────────┐
                                                 │ Authenticate    │
                                                 │ POST /Users/    │
                                                 │ AuthenticateBy  │
                                                 │ Name            │
                                                 └─────────────────┘
                                                          │
                                            ┌─────────────┴─────────────┐
                                            │                           │
                                            ▼                           ▼
                                    ┌──────────────┐           ┌──────────────┐
                                    │ Auth Failed  │           │ Auth Success │
                                    └──────────────┘           └──────────────┘
                                            │                           │
                                            ▼                           ▼
                                    ┌──────────────┐           ┌──────────────┐
                                    │ Show Error   │           │ Save Session │
                                    │ Try Again    │           │ to Keychain  │
                                    └──────────────┘           └──────────────┘
                                                                        │
                                                                        ▼
                                                               ┌─────────────────┐
                                                               │   HomeView      │
                                                               │ (Authenticated) │
                                                               └─────────────────┘
                                                                        │
                                                                        ▼
                                                               ┌─────────────────┐
                                                               │ User Clicks     │
                                                               │ "Sign Out"      │
                                                               └─────────────────┘
                                                                        │
                                                                        ▼
                                                               ┌─────────────────┐
                                                               │ Clear Keychain  │
                                                               │ Clear Session   │
                                                               └─────────────────┘
                                                                        │
                                                                        ▼
                                                               ┌─────────────────┐
                                                               │ ServerEntryView │
                                                               └─────────────────┘
```

## Component Responsibilities

### MediaMioApp.swift
- **Role**: Root app controller
- **Logic**:
  - Observes `AuthenticationService.isAuthenticated`
  - Routes to `ServerEntryView` or `HomeView` based on auth state

### AuthenticationService
- **Role**: Centralized authentication state manager
- **Responsibilities**:
  - Session management
  - Keychain operations
  - Auto-restore on app launch
  - Login/logout coordination

### JellyfinAPIClient
- **Role**: HTTP networking layer
- **Responsibilities**:
  - Build requests with proper headers
  - Handle authentication tokens
  - Execute API calls
  - Decode JSON responses

### ServerEntryViewModel
- **Role**: Server connection logic
- **State**:
  - `serverURL`: User input
  - `isLoading`: Connection test in progress
  - `errorMessage`: Connection errors
  - `isConnected`: Success state

### LoginViewModel
- **Role**: Login form logic
- **State**:
  - `username`: User input
  - `password`: User input
  - `rememberMe`: Persistence preference
  - `isLoading`: Login in progress
  - `errorMessage`: Auth errors

## API Calls

### 1. Test Server Connection
```
GET http://<server>/System/Info
Headers:
  X-Emby-Authorization: MediaBrowser Client="MediaMio", Device="Apple TV", DeviceId="<uuid>", Version="1.0.0"

Response:
{
  "Id": "server-id",
  "ServerName": "My Jellyfin Server",
  "Version": "10.8.13",
  "OperatingSystem": "Linux"
}
```

### 2. Authenticate User
```
POST http://<server>/Users/AuthenticateByName
Headers:
  X-Emby-Authorization: MediaBrowser Client="MediaMio", Device="Apple TV", DeviceId="<uuid>", Version="1.0.0"
  Content-Type: application/json

Body:
{
  "Username": "user",
  "Pw": "password"
}

Response:
{
  "User": {
    "Id": "user-id",
    "Name": "username",
    "ServerId": "server-id",
    "HasPassword": true
  },
  "AccessToken": "auth-token-here",
  "ServerId": "server-id"
}
```

## Keychain Storage

### Saved Data
```
Service: com.mediamio.jellyfin

Keys:
- serverURL: "http://192.168.1.100:8096"
- username: "john"
- accessToken: "authentication-token"
- userId: "user-id-from-server"
```

### UserDefaults (Non-Sensitive)
```
Keys:
- rememberMe: true/false
- lastServerURL: "http://192.168.1.100:8096" (for convenience)
- lastUsername: "john" (for convenience)
- deviceId: "persistent-device-uuid"
```

## Error Handling

### Network Errors
- **Invalid URL**: User-friendly message
- **Server Unreachable**: Connection timeout message
- **HTTP Errors**: Status code displayed
- **Auth Failed**: Invalid credentials message

### Recovery Actions
- All errors allow retry
- User can go back to previous screen
- Error messages are cleared on new attempts

## Security Considerations

### ✅ Implemented
- Keychain for sensitive data
- HTTPS support
- Token-based authentication
- Secure session management
- Clean logout (clears all data)

### 🔜 Future Enhancements (Later Phases)
- Certificate pinning
- Biometric authentication
- Session timeout
- Token refresh
- Multiple user profiles

## Testing Scenarios

### Happy Path
1. Enter server URL → Connection success
2. Enter credentials → Login success
3. See home screen
4. Restart app → Auto-login to home screen

### Error Scenarios
1. Invalid URL format → Show error, allow correction
2. Server unreachable → Show error, allow retry
3. Wrong password → Show error, allow retry
4. Network timeout → Show error, allow retry

### State Management
1. Sign out → Returns to server entry
2. Disable remember me → No auto-login on restart
3. Change server → Previous credentials cleared
