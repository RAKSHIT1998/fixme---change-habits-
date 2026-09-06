import Foundation
import UIKit

/// Local-only storage for evidence and daily photos. Nothing here ever leaves the device
/// unless the user explicitly shares/exports it. Callers should offer users a way to
/// delete verification photos after a result is recorded (see `deleteImage`).
enum ImageStore {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("FixMePhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    @discardableResult
    static func save(_ image: UIImage, quality: CGFloat = 0.85) -> String? {
        guard let data = image.jpegData(compressionQuality: quality) else { return nil }
        let fileName = "\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    static func load(_ fileName: String) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(fileName).path)
    }

    static func deleteImage(_ fileName: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }

    static func allFileNames() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    }

    /// Removes every stored photo. Backs the "Delete my photos" control in Settings.
    @discardableResult
    static func deleteAll() -> Int {
        let names = allFileNames()
        for name in names { deleteImage(name) }
        return names.count
    }
}
