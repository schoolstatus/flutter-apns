import Foundation
import UIKit
import UserNotifications

@objc class FlutterApnsSwizzler: NSObject {
  @objc static func swizzle() {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = UIApplication.shared.delegate as? UNUserNotificationCenterDelegate
    }
  }
}
