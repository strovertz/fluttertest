import Cocoa
import FlutterMacOS

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    GMSServices.provideAPIKey("AIzaSyBEXDD_vKYyk8Mg65jL_da8prvBGEh0_20")
    return true
  }
}
