# AGENTS.md — expo-google-native-oauth

This document provides instructions and context for AI coding agents working in this repository.

## Ecosystem Context

> **This module handles Google Sign-In for the DeezChatz messaging app.** It is standalone — no dependency on `libsignal-dezire` or any crypto libraries.

```
deezchatz-mobile  →  ⭐ expo-google-native-oauth (this module)  →  Google OAuth (native SDKs)
                                                                    │
                                                              idToken (JWT)
                                                                    │
                                                              deezchatz-api
                                                              POST /register/google/id_token
```

| Relationship | Details |
|-------------|---------|
| **Used by** | `deezchatz-mobile` — as a dependency for the registration flow |
| **Sends data to** | `deezchatz-api` — the `idToken` JWT is sent to the backend's `/register/google/id_token` endpoint |
| **No dependency on** | `libsignal-dezire` or `expo-libsignal-dezire` — this is purely an OAuth module |

### Cross-Repo Impact

- **If you change the `GoogleSignInResult` type shape**: `nijhum-mobile`'s registration flow consumes these fields.
- **If you change error codes**: `nijhum-mobile` catches specific `ERR_GOOGLE_AUTH_*` codes.
- **If you change the config plugin behavior**: all apps using this module need to `npx expo prebuild --clean`.

---

## Commands

```bash
# Build TypeScript + config plugin
bun run build

# Build only the config plugin
bun run build:plugin

# Clean all build artifacts
bun run clean

# Lint
bun lint

# Prepare for publish (TypeScript compile + plugin build)
bun run prepare
```

> **No test suite currently exists.** Testing is done manually by running the sign-in flow on a device/simulator.

---

## Project Structure

```
src/
  index.ts                         # Public API: signIn(), signOut(), isAvailable()
  ExpoGoogleNativeOauth.types.ts   # TypeScript types (GoogleSignInResult, SignInOptions)
  ExpoGoogleNativeOauthModule.ts   # Native module import wrapper

ios/
  ExpoGoogleNativeOauthModule.swift  # Swift implementation using GIDSignIn SDK
  ExpoGoogleNativeOauth.podspec     # CocoaPods spec (depends on GoogleSignIn pod)

android/
  build.gradle                       # Gradle config (depends on CredentialManager)
  src/                               # Kotlin implementation

plugin/
  src/
    index.ts                         # Expo config plugin — injects Client IDs into native configs
  tsconfig.json                      # Plugin-specific TypeScript config

app.plugin.js                        # Entry point for the config plugin
expo-module.config.json              # Expo module registration
package.json                         # Package metadata
```

---

## Native Code Details

### iOS (GIDSignIn)

- `ExpoGoogleNativeOauthModule.swift` calls `GIDSignIn.sharedInstance.signIn()`.
- Reads `GIDClientID` and `GIDWebClientID` from `Info.plist` (injected by config plugin).
- The reverse-client-ID URL scheme is needed for the sign-in callback.
- Minimum iOS version: 15.1.

### Android (CredentialManager)

- Uses `androidx.credentials.CredentialManager` (modern API, replaces deprecated `GoogleSignInClient`).
- The Android Client ID is read from `AndroidManifest.xml` meta-data (injected by config plugin).
- The Web Client ID is passed as the `serverClientId` in the `GetGoogleIdTokenCredentialOption` request.
- Minimum API level: 24.

### Config Plugin (`plugin/src/index.ts`)

The config plugin runs during `npx expo prebuild` and modifies:

**iOS**:
- Sets `GIDClientID` in `Info.plist`
- Sets `GIDWebClientID` in `Info.plist`
- Adds reverse-client-ID to `CFBundleURLTypes`

**Android**:
- Adds `com.google.android.gms.auth.ANDROID_CLIENT_ID` to `<application>` meta-data in `AndroidManifest.xml`

**Testing config plugin changes**: Always run `npx expo prebuild --clean` after modifying the plugin to verify the output in `ios/` and `android/` directories.

---

## Types

```typescript
// The result of a successful sign-in
type GoogleSignInResult = {
  idToken: string | null;       // JWT — send to backend for verification
  googleUserId: string;         // Google's unique user ID
  email: string | null;
  displayName: string | null;
  avatarUrl: string | null;
};

// Optional configuration for sign-in
type SignInOptions = {
  scopes?: string[];            // Additional OAuth scopes
};
```

The `idToken` is a JWT signed by Google. Its `aud` (audience) claim is set to the **Web Client ID**. The backend (`nijhum-api`) verifies this token by checking the signature against Google's JWKS and matching the audience to its `GOOGLE_CLIENT_ID` environment variable.

---

## Error Codes

| Code | When it fires |
|------|--------------|
| `ERR_GOOGLE_AUTH_CANCELLED` | User dismissed the native sign-in dialog |
| `ERR_GOOGLE_AUTH_UNAVAILABLE` | No active Android Activity or React context available |
| `ERR_GOOGLE_AUTH_CONFIGURATION` | `webClientId` is missing from the plugin config |
| `ERR_GOOGLE_AUTH_FAILED` | Generic failure (check `error.message` for details) |
| `ERR_GOOGLE_AUTH_NO_VIEW_CONTROLLER` | iOS: couldn't find a root view controller to present the sign-in UI |
| `ERR_GOOGLE_AUTH_CONFIG` | iOS: `GIDClientID` not found in `Info.plist` |

---

## Code Style

- **TypeScript**: Standard Expo module conventions. Strict types, no `any`.
- **Swift**: Standard Swift style. One file implementation.
- **Kotlin**: Standard Android/Kotlin conventions.
- **Config Plugin**: TypeScript. Uses `@expo/config-plugins` API.
