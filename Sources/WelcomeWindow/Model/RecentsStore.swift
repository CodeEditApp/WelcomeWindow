import AppKit
import CoreSpotlight
import OSLog

/// A utility store for managing recent project file access using security-scoped bookmarks.
@MainActor
public enum RecentsStore {

    /// The UserDefaults key for storing recent project bookmarks.
    private static let bookmarksKey = "recentProjectBookmarks"

    /// Notification sent when the recent projects list is updated.
    public static let didUpdateNotification = Notification.Name("RecentsStore.didUpdate")

    /// For tests (or previews) before any API call.
    public static var defaults: UserDefaults = .standard

    /// Internal representation of a bookmark entry.
    private struct BookmarkEntry: Codable, Equatable {
        /// The standardized file path of the bookmarked URL.
        let urlPath: String

        /// The bookmark data associated with the URL.
        let bookmarkData: Data

        /// Resolves and returns the `URL` from the bookmark data, or `nil` if resolution fails.
        var url: URL? {
            var isStale = false
            return try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withoutUI, .withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        }

        static func == (lhs: BookmarkEntry, rhs: BookmarkEntry) -> Bool {
            lhs.urlPath == rhs.urlPath
        }
    }

    private nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.example.app",
        category: "RecentsStore"
    )

    // MARK: - Public API

    /// Returns an array of all recent project URLs resolved from stored bookmarks.
    ///
    /// - Returns: An array of `URL` representing the recent projects.
    public static func recentProjectURLs() -> [URL] {
        var seen = Set<String>()
        return loadBookmarks().compactMap { entry in
            guard let resolved = entry.url else { return nil }
            guard !isInTrash(resolved) else { return nil }
            let path = resolved.standardized.path
            guard !seen.contains(path) else { return nil }
            seen.insert(path)
            return resolved
        }
    }

    // MARK: - Folder / file specific access
    /// Recent entries that are directories (projects that live in folders, asset catalogs, …)
    public static func recentDirectoryURLs() -> [URL] {
        filterURLs { $0.isDirectory }
    }

    /// Recent entries that are regular files (App documents, text files, …)
    public static func recentFileURLs() -> [URL] {
        filterURLs { !$0.isDirectory }
    }

    /// Notifies the store that a project was opened.
    ///
    /// This saves a security-scoped bookmark for the URL and moves it to the top of the recent list.
    ///
    /// - Parameter url: The file URL of the opened document.
    public static func documentOpened(at url: URL) {
        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var bookmarks = loadBookmarks()

            let standardizedPath = url.standardized.path
            bookmarks.removeAll(where: { $0.urlPath == standardizedPath })
            bookmarks.insert(BookmarkEntry(urlPath: standardizedPath, bookmarkData: bookmark), at: 0)

            saveBookmarks(Array(bookmarks.prefix(100)))
        } catch {
            print("❌ Failed to create bookmark for recent project: \(error)")
        }
    }

    /// Removes specific project URLs from the recent list.
    ///
    /// - Parameter urlsToRemove: A set of URLs to remove from the recent projects list.
    /// - Returns: The updated list of recent project URLs.
    public static func removeRecentProjects(_ urlsToRemove: Set<URL>) -> [URL] {
        var bookmarks = loadBookmarks()
        bookmarks.removeAll(where: { entry in
            urlsToRemove.contains(where: { $0.path == entry.urlPath })
        })
        saveBookmarks(bookmarks)
        return recentProjectURLs()
    }

    /// Clears all stored recent project bookmarks.
    public static func clearList() {
        saveBookmarks([])
    }

    // MARK: - Bookmark Access

    /// Begins accessing a security-scoped resource before opening a project.
    ///
    /// - Parameter url: The URL of the project to access.
    /// - Returns: `true` if access began successfully; otherwise, `false`.
    public static func beginAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    /// Ends access to a previously accessed security-scoped resource.
    ///
    /// - Parameter url: The URL of the project to stop accessing.
    public static func endAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }

    // MARK: - Internal

    /// Filters URLs based on a condition, used to separate files and folders.
    ///
    /// - Parameter filter: Closure to determine if the URL should be included.
    /// - Returns: An array of `URL` that match the filter condition.
    private static func filterURLs(by filter: (URL) -> Bool) -> [URL] {
        var seen = Set<String>()
        return loadBookmarks().compactMap { entry in
            guard let resolved = entry.url,
                  !isInTrash(resolved),
                  filter(resolved)
            else { return nil }

            let path = resolved.standardized.path
            guard !seen.contains(path) else { return nil }
            seen.insert(path)
            return resolved
        }
    }

    /// Returns `true` when the url resides in a macOS Trash folder.
    private static func isInTrash(_ url: URL) -> Bool {
        let comps = url.standardized.pathComponents
        //  ~/.Trash/...              → ".Trash"
        //  /Volumes/Disk/.Trashes/501/...  → ".Trashes"
        return comps.contains(".Trash") || comps.contains(".Trashes")
    }

    /// Loads the stored bookmarks from UserDefaults.
    ///
    /// - Returns: An array of `BookmarkEntry` values decoded from UserDefaults.
    private static func loadBookmarks() -> [BookmarkEntry] {
        guard let data = defaults.data(forKey: bookmarksKey),
                let decoded = try? PropertyListDecoder().decode([BookmarkEntry].self, from: data)
        else { return [] }
        return decoded
    }

    /// Saves an array of bookmark entries to UserDefaults and posts an update notification.
    ///
    /// - Parameter entries: The bookmark entries to save.
    private static func saveBookmarks(_ entries: [BookmarkEntry]) {
        guard let data = try? PropertyListEncoder().encode(entries) else { return }
        defaults.set(data, forKey: bookmarksKey)
        NotificationCenter.default.post(name: didUpdateNotification, object: nil)
    }

    /// Donates all recent URLs to CoreSpotlight, making them searchable in Spotlight.
    private static func donateSearchableItems() {
        let searchableItems = recentProjectURLs().map { url in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
            attributeSet.title = url.lastPathComponent
            attributeSet.contentDescription = "Recent project in \(Bundle.displayName)."
            attributeSet.relatedUniqueIdentifier = url.path
            return CSSearchableItem(
                uniqueIdentifier: url.path,
                domainIdentifier: "\(Bundle.mainBundleIdentifier).ProjectItem",
                attributeSet: attributeSet
            )
        }
        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error = error {
                logger.error("Failed to donate recent projects, error: \(error.localizedDescription)")
            }
        }
    }
}
