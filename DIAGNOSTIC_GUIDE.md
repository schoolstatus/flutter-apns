# APN Events Debugging Guide

## Current Status
✅ You're receiving the device token (registration works)  
❓ Not receiving APN events (onMessage, onResume, onLaunch)

## Step-by-Step Debugging

### 1. Check iOS Capabilities
Ensure your app has the **Push Notifications** capability enabled:
- Open your project in Xcode
- Select your target → Signing & Capabilities
- Verify "Push Notifications" is listed
- If not, click "+ Capability" and add it

### 2. Check AppDelegate Setup
Your `AppDelegate.swift` should look like this:

```swift
import UIKit
import Flutter
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // IMPORTANT: Register plugins FIRST
        GeneratedPluginRegistrant.register(with: self)
        
        // THEN set the delegate
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("PUSH registration failed: \(error)")
    }
}
```

### 3. Check Console Logs
The package now has extensive logging. When you run the app and send a push notification, you should see logs like:

**On App Start:**
```
[FlutterApns] configure called
[FlutterApns] Current delegate: <AppDelegate: 0x...>
[FlutterApns] configureApns called
[FlutterApns] onMessage: provided
[FlutterApns] onLaunch: provided
[FlutterApns] onResume: provided
```

**When Push Arrives (Foreground):**
```
[FlutterApns] userNotificationCenter willPresent called
[FlutterApns] notification userInfo: {...}
[FlutterApns] Calling onMessage from willPresent
[FlutterApns] Dart received method call: onMessage
```

**When Push Arrives (Background/Tapped):**
```
[FlutterApns] userNotificationCenter didReceive response called
[FlutterApns] response userInfo: {...}
[FlutterApns] Calling onResume from didReceive
[FlutterApns] Dart received method call: onResume
```

### 4. Test Your Push Notification Payload

The issue might be with your push notification format. For iOS, use this format:

**Minimum payload:**
```json
{
  "aps": {
    "alert": "Test message",
    "sound": "default"
  }
}
```

**Full payload example:**
```json
{
  "aps": {
    "alert": {
      "title": "Test Title",
      "body": "Test message body"
    },
    "badge": 1,
    "sound": "default"
  },
  "customData": "value"
}
```

### 5. Send Test Push Notification

Use this curl command (replace placeholders):

```bash
curl -v \
-d '{"aps":{"alert":"Test from curl","badge":1,"sound":"default"}}' \
-H "apns-topic: <YOUR_BUNDLE_ID>" \
-H "apns-priority: 10" \
--http2 \
--cert <PATH_TO_YOUR_CERT>.pem \
https://api.sandbox.push.apple.com/3/device/<YOUR_DEVICE_TOKEN>
```

For production:
```bash
https://api.push.apple.com/3/device/<YOUR_DEVICE_TOKEN>
```

### 6. Check What Logs You're Seeing

Run your app and send a test push. Check the console for:

**If you see NO FlutterApns logs at all:**
- The plugin isn't properly registered
- Check that you're calling `connector.configure()` in your Dart code
- Verify `GeneratedPluginRegistrant.register(with: self)` is called

**If you see configure logs but no notification logs:**
- Your push notification isn't reaching the device
- Check your certificate/token is valid
- Verify you're using the correct environment (sandbox vs production)
- Check device token is correct

**If you see willPresent/didReceive logs but no Dart logs:**
- The method channel isn't working
- This would be a Flutter plugin system issue

**If you see all logs up to "Dart received method call" but your handler isn't called:**
- Check your Dart code is properly setting up the handlers
- Verify no exceptions in your handler code

### 7. Common Issues

**Issue: Configure assertion fails**
```
UNUserNotificationCenter.current().delegate is not set
```
**Fix:** Set the delegate in AppDelegate as shown in step 2

**Issue: Token received but no events**
- Check push notification payload has "aps" key
- Verify certificate matches environment (sandbox vs production)
- Check Info.plist has proper background modes if testing background

**Issue: Events work in foreground but not background**
- Add "Remote notifications" background mode in Xcode
- Target → Signing & Capabilities → Background Modes → ✅ Remote notifications

### 8. Next Steps

After adding the logging:

1. **Clean build:**
   ```bash
   cd ios
   pod install
   cd ..
   flutter clean
   flutter pub get
   ```

2. **Run the app** and watch the console

3. **Send a test push** using curl or your push service

4. **Share the logs** - Look for all lines starting with `[FlutterApns]`

### 9. Verify Your Dart Code

Make sure your Dart code looks like this:

```dart
final connector = createPushConnector();

// Configure FIRST (ideally in initState or main)
connector.configure(
  onMessage: (RemoteMessage message) async {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');
  },
  onLaunch: (RemoteMessage message) async {
    print('App opened from terminated state');
    print('Message data: ${message.data}');
  },
  onResume: (RemoteMessage message) async {
    print('App opened from background');
    print('Message data: ${message.data}');
  },
);

// Then request permissions
connector.requestNotificationPermissions();

// Optional: For iOS, control foreground presentation
if (connector is ApnsPushConnector) {
  connector.shouldPresent = (x) async {
    return true; // Show notification even in foreground
  };
}
```

### 10. Quick Test Checklist

- [ ] Push Notifications capability enabled in Xcode
- [ ] AppDelegate properly configured (plugins registered BEFORE delegate set)
- [ ] connector.configure() called with all handlers
- [ ] connector.requestNotificationPermissions() called
- [ ] Device token printed in console
- [ ] Push payload includes "aps" key
- [ ] Using correct APNS environment (sandbox/production)
- [ ] Certificate/token is valid and matches bundle ID
- [ ] Running on physical device (not simulator for iOS < 11.4)

## Still Not Working?

Share the following information:
1. All console logs with `[FlutterApns]` prefix
2. Your AppDelegate.swift code
3. Your Dart configuration code
4. The push payload you're sending
5. iOS version and device model
6. Whether you're using sandbox or production APNS
