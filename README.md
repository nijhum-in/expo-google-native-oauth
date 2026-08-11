# expo-google-native-oauth

[![npm](https://img.shields.io/npm/v/expo-google-native-oauth.svg)](https://www.npmjs.com/package/expo-google-native-oauth)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-lightgrey)]()

Native Google Sign-In for Expo apps using **GIDSignIn** (iOS) and **CredentialManager** (Android). No browser redirects — this triggers the platform's native sign-in UI for a seamless experience.

## Where This Fits

```
┌──────────────────────────────────────────────┐
│  DeezChatz Mobile (React Native app)         │
│    │                                         │
│    ├─ ⭐ expo-google-native-oauth (this)     │ ← User taps "Sign In with Google"
│    │     └─ Returns idToken (JWT)            │
│    │                                         │
│    └─ Sends idToken to ──────────────────────┼──→ DeezChatz API
│                                              │     POST /register/google/id_token
└──────────────────────────────────────────────┘
```

In the DeezChatz ecosystem, this module handles **Registration Phase 1**:

1. User taps "Sign In with Google" in the app.
2. This module triggers the native Google Sign-In flow.
3. Google returns an `idToken` (a JWT containing the user's email, name, and profile picture).
4. The app sends this `idToken` to the DeezChatz API at `POST /register/google/id_token`.
5. The API verifies the token with Google's JWKS and creates a pending registration.
6. Registration Phase 2 (crypto key upload) then happens via [expo-libsignal-dezire](https://github.com/deez-in/expo-libsignal-dezire).

### Why Native Instead of Web-Based OAuth?

| | Native (this module) | Web-based (`expo-auth-session`) |
|---|---|---|
| **UX** | Platform credential picker — no browser redirect | Opens a browser tab, then redirects back |
| **Token type** | Real `idToken` (JWT) signed by Google | Authorization code that needs server-side exchange |
| **Security** | Tied to app signing cert (Android) / bundle ID (iOS) | Relies on redirect URI validation |
| **Offline** | Works with CredentialManager's saved credentials | Requires network for the browser flow |

---

## Installation

```bash
bun add expo-google-native-oauth
# or
npm install expo-google-native-oauth
```

After installing, rebuild your native project:

```bash
npx expo prebuild
```

> **Note**: This module requires a custom dev client (Expo development build). It will not work with Expo Go.

---

## Google Cloud Console Setup

You need **three** OAuth 2.0 Client IDs from the [Google Cloud Console](https://console.cloud.google.com/apis/credentials). Here's what each one does:

| Type | Purpose | How Google identifies the requester |
|------|---------|-------------------------------------|
| **Android** | Identifies your Android app | SHA-1 fingerprint of your app's signing certificate + package name |
| **iOS** | Identifies your iOS app | Bundle ID |
| **Web application** | Sets the `audience` on the JWT | The `idToken` is signed with this Client ID as the audience — your backend uses it to verify the token |

> [!IMPORTANT]
> The **Web application** Client ID is what makes the `idToken` verifiable on your backend. Without it, the token's `aud` field won't match what your server expects, and you'll get `InvalidAudience` errors when verifying with Google's JWKS.

### Step by step:

1. Go to [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials).
2. Create an **Android** OAuth Client ID (requires your app's SHA-1 signing cert — get it with `./gradlew signingReport`).
3. Create an **iOS** OAuth Client ID (requires your bundle ID from Xcode).
4. Create a **Web application** OAuth Client ID (no restrictions needed for mobile use).

---

## Configuration

Add the plugin to your `app.json` or `app.config.ts`:

```json
{
  "plugins": [
    [
      "expo-google-native-oauth",
      {
        "androidClientId": "YOUR_ANDROID_CLIENT_ID.apps.googleusercontent.com",
        "iosClientId": "YOUR_IOS_CLIENT_ID.apps.googleusercontent.com",
        "webClientId": "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com"
      }
    ]
  ]
}
```

Or with environment variables in `app.config.ts`:

```typescript
export default {
  plugins: [
    [
      "expo-google-native-oauth",
      {
        androidClientId: process.env.EXPO_PUBLIC_GOOGLE_ANDROID_CLIENT_ID,
        iosClientId: process.env.EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID,
        webClientId: process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID,
      },
    ],
  ],
};
```

### What the Config Plugin Handles Automatically

You don't need to touch native config files. The plugin injects:

- **iOS** (`Info.plist`):
  - `GIDClientID` → your iOS Client ID
  - `GIDWebClientID` → your Web Client ID
  - `CFBundleURLTypes` → reverse-client-ID URL scheme (required by GIDSignIn SDK)
- **Android** (`AndroidManifest.xml`):
  - `com.google.android.gms.auth.ANDROID_CLIENT_ID` meta-data tag

---

## Usage

```typescript
import * as GoogleAuth from "expo-google-native-oauth";
```

### `signIn(options?)`

Triggers the native Google Sign-In flow. Returns user credentials including a JWT `idToken`.

```typescript
try {
  const result = await GoogleAuth.signIn();

  console.log(result.idToken);      // JWT — send this to your backend
  console.log(result.email);        // "user@gmail.com"
  console.log(result.displayName);  // "Jane Doe"
  console.log(result.avatarUrl);    // Profile picture URL
  console.log(result.googleUserId); // Google's unique user ID
} catch (e) {
  console.error("Sign-in failed:", e);
}
```

**Sending the token to your backend:**

```typescript
const result = await GoogleAuth.signIn();

const response = await fetch("https://your-api.com/register/google/id_token", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ idToken: result.idToken }),
});

const { userId } = await response.json();
// userId is now available for Phase 2 (crypto key upload)
```

**Requesting additional scopes:**

```typescript
const result = await GoogleAuth.signIn({
  scopes: ["https://www.googleapis.com/auth/calendar.readonly"],
});
```

### `signOut()`

Signs the user out and clears credentials from the native session.

```typescript
await GoogleAuth.signOut();
```

### `isAvailable()`

Returns `true` if the native module is loaded on the current platform. Useful for guarding calls on web or unsupported environments.

```typescript
if (GoogleAuth.isAvailable()) {
  // Safe to call signIn()
}
```

---

## Return Type

```typescript
type GoogleSignInResult = {
  idToken: string | null;       // JWT — send this to your backend for verification
  googleUserId: string;         // Google's unique identifier for this user
  email: string | null;         // User's email address
  displayName: string | null;   // User's display name
  avatarUrl: string | null;     // URL to profile picture
};

type SignInOptions = {
  scopes?: string[];            // Additional OAuth scopes beyond basic profile
};
```

---

## Error Codes

| Code | Description | Common cause |
|------|-------------|--------------|
| `ERR_GOOGLE_AUTH_CANCELLED` | User dismissed the sign-in dialog | User tapped outside the dialog or pressed back |
| `ERR_GOOGLE_AUTH_UNAVAILABLE` | No active Android Activity or React context | App is in the background or not fully initialized |
| `ERR_GOOGLE_AUTH_CONFIGURATION` | Missing `webClientId` | Plugin config is incomplete — check `app.config.ts` |
| `ERR_GOOGLE_AUTH_FAILED` | Generic sign-in failure | Check the error message for specifics (network, API key mismatch, etc.) |
| `ERR_GOOGLE_AUTH_NO_VIEW_CONTROLLER` | iOS: no root view controller found | Rare — usually means the app UI isn't ready yet |
| `ERR_GOOGLE_AUTH_CONFIG` | iOS: `GIDClientID` missing from `Info.plist` | Run `npx expo prebuild --clean` to regenerate native config |

---

## Platform Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS | 15.1 |
| Android | API 24 (Android 7.0) |

---

## License

MIT — Debarka Mondal
