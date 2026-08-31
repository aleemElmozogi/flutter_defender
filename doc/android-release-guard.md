# Android release launch guard

`enableEmulatorDetectionRelease` blocks guarded Flutter screens in release
builds. The optional native launch guard applies the same release-only policy
before Flutter starts.

Debug and profile builds remain runnable on emulators. Android may still install
a release APK on a compatible emulator; the guard enforces the policy when the
app launches, not during installation.

## 1. Update the existing MainActivity

Edit the existing `.MainActivity` declaration in place:

- Set `android:exported="false"`.
- Keep its existing theme, launch mode, configuration, and Flutter metadata.
- Remove its entire `MAIN`/`LAUNCHER` intent filter.

```xml
<activity
    android:name=".MainActivity"
    android:exported="false"
    android:launchMode="singleTop"
    android:taskAffinity=""
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">
    <meta-data
        android:name="io.flutter.embedding.android.NormalTheme"
        android:resource="@style/NormalTheme" />
</activity>
```

Do not add another `.MainActivity` declaration. Android merges activities by
`android:name`; a second declaration without an intent filter does not remove
the launcher filter from the original declaration.

If `.MainActivity` handles external deep links, design a separate guarded entry
path before removing or changing those filters.

## 2. Add the guard activity

Add this activity as a sibling of `.MainActivity` inside the same
`<application>` element:

```xml
<activity
    android:name="aleem.flutter.defender.ReleaseEmulatorGuardActivity"
    android:excludeFromRecents="true"
    android:exported="true"
    android:finishOnTaskLaunch="true"
    android:launchMode="singleTask"
    android:noHistory="true"
    android:taskAffinity=""
    android:theme="@style/LaunchTheme"
    tools:replace="android:exported">
    <meta-data
        android:name="aleem.flutter.defender.TARGET_ACTIVITY"
        android:value=".MainActivity" />

    <!-- Optional text overrides:
    <meta-data
        android:name="aleem.flutter.defender.BLOCK_TITLE"
        android:value="Unsupported device" />
    <meta-data
        android:name="aleem.flutter.defender.BLOCK_SUBTITLE"
        android:value="Security protection is enabled" />
    <meta-data
        android:name="aleem.flutter.defender.BLOCK_MESSAGE"
        android:value="This release build cannot run on emulators." />
    <meta-data
        android:name="aleem.flutter.defender.BLOCK_BUTTON"
        android:value="Close app" />
    -->

    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
    </intent-filter>
</activity>
```

If the root `<manifest>` does not already declare the tools namespace, add it:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
```

No Gradle change is required. `TARGET_ACTIVITY` must resolve to the real Flutter
activity. A configuration error is displayed and logged when it does not.

## 3. Verify the merged manifest

Open Android Studio's **Merged Manifest** view for the release variant and
confirm:

- `ReleaseEmulatorGuardActivity` is the only activity with both `MAIN` and
  `LAUNCHER`.
- `.MainActivity` is not exported.
- `TARGET_ACTIVITY` points to `.MainActivity` or the host app's real Flutter
  activity.

Two launcher activities produce two icons. An exported target activity can be
started directly and bypass the native launcher guard.
