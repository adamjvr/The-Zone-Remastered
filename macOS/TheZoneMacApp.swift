import SwiftUI

@main struct TheZoneMacApp: App {
  var body: some Scene {
    WindowGroup("The Zone Remastered") { ZoneContentView().frame(minWidth: 640, minHeight: 480) }
      .windowStyle(.automatic)
  }
}
