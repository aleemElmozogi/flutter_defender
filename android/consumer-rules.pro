-keep class aleem.flutter.defender.ReleaseEmulatorGuardActivity { *; }
-keep class aleem.flutter.defender.EmulatorDetector { *; }

# androidx.security:security-crypto pulls Tink, which references compile-time
# annotation packages that are not needed at runtime.
-dontwarn com.google.errorprone.annotations.CanIgnoreReturnValue
-dontwarn com.google.errorprone.annotations.CheckReturnValue
-dontwarn com.google.errorprone.annotations.Immutable
-dontwarn com.google.errorprone.annotations.RestrictedApi
-dontwarn javax.annotation.Nullable
-dontwarn javax.annotation.concurrent.GuardedBy
