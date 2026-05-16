import Foundation

extension Foundation.Bundle {
    static nonisolated let module: Bundle = {
        let mainPath = Bundle.main.bundleURL.appendingPathComponent("PwgUploadKit_PwgUploadKit.bundle").path
        let buildPath = "/Users/lelievre/Privé - GitHub/Piwigo-Mobile/PwgUploadKit/.build/arm64-apple-macosx/debug/PwgUploadKit_PwgUploadKit.bundle"

        let preferredBundle = Bundle(path: mainPath)

        guard let bundle = preferredBundle ?? Bundle(path: buildPath) else {
            // Users can write a function called fatalError themselves, we should be resilient against that.
            Swift.fatalError("could not load resource bundle: from \(mainPath) or \(buildPath)")
        }

        return bundle
    }()
}