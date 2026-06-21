import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var rollCallPackage: UTType {
        UTType("com.jkfisher.rollcall.package")
            ?? UTType(exportedAs: "com.jkfisher.rollcall.package", conformingTo: .data)
    }
}

@main
struct RollCallApp: App {
    @StateObject private var appModel = AppModel()

    init() {
        StoreKitSupportTransactionObserver.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView(appModel: appModel)
        }
    }
}
