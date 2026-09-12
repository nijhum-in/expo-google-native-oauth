# ProGuard rules for expo-google-native-oauth

# Keep the module class and its members
-keep class com.dezire.expogooglenativeoauth.** { *; }

# Keep Google Identity classes
-keep class com.google.android.libraries.identity.googleid.** { *; }

# Keep Credential Manager classes that use CustomCredential via reflection
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.** { *; }
