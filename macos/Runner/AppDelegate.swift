import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var pendingFilePath: String?
  private var methodChannel: FlutterMethodChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let window = mainFlutterWindow,
       let controller = window.contentViewController as? FlutterViewController {
      methodChannel = FlutterMethodChannel(name: "cpredux/file_open", binaryMessenger: controller.engine.binaryMessenger)
      methodChannel?.setMethodCallHandler { [weak self] (call, result) in
        if call.method == "getInitialFile" {
          let file = self?.pendingFilePath
          self?.pendingFilePath = nil
          result(file)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
      if let file = pendingFilePath {
        pendingFilePath = nil
        methodChannel?.invokeMethod("onOpenFile", arguments: file)
      }
    }
    super.applicationDidFinishLaunching(notification)
  }

  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    if let channel = methodChannel {
      channel.invokeMethod("onOpenFile", arguments: filename)
    } else {
      pendingFilePath = filename
    }
    return true
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

