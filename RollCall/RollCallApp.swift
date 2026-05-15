import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var rollCallPackage: UTType {
        UTType(exportedAs: "com.jkfisher.rollcall.package", conformingTo: .zip)
    }
}

@main
struct RollCallApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(appModel: appModel)
        }
    }
}
