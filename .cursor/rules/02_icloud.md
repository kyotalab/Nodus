# PHASE 3: iCloud Drive Integration
> Active during: Replacing dummy data with real file I/O via iCloud Drive
> Always read 00_project.md alongside this file.

## Goal of This Phase
Replace NoteStore's hardcoded array with real .md files stored in
iCloud Drive. The app should read, create, update, and delete files.

## iCloud Setup Checklist (Xcode)
- [ ] Signing & Capabilities → + Capability → iCloud
- [ ] Check "iCloud Documents"
- [ ] Container: `iCloud.com.YOURNAME.Nodus`
- [ ] Info.plist: Add `NSUbiquitousContainers` key (Xcode generates this)

## Container Strategy
Use the **ubiquity container** (not CloudKit).
This makes files visible in Files.app and compatible with any Markdown editor on macOS.

## First Launch: Folder Selection
On first launch, present a folder picker so the user can select their existing
Zettelkasten folder. This allows sharing with The Archive or any other editor.

```swift
// Pseudocode for folder picker
func presentFolderPicker() {
    let picker = UIDocumentPickerViewController(
        forOpeningContentTypes: [.folder]
    )
    picker.delegate = self
    present(picker, animated: true)
}

// On selection: save as security-scoped bookmark
func documentPicker(_ controller: UIDocumentPickerViewController,
                    didPickDocumentsAt urls: [URL]) {
    guard let url = urls.first else { return }
    let bookmark = try url.bookmarkData(
        options: .minimalBookmark,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
    )
    UserDefaults.standard.set(bookmark, forKey: "selectedFolderBookmark")
}
```

| Item | Detail |
|------|--------|
| Trigger | First launch only (or when folder not set) |
| Picker scope | iCloud Drive folders only |
| Persistence | Security-scoped bookmark in UserDefaults |
| Change folder | Available in Settings screen |
| Compatibility | User selects same folder used by The Archive / Zettlr / iA Writer |

```swift
// Getting the iCloud container URL
func iCloudContainerURL() -> URL? {
    FileManager.default.url(
        forUbiquityContainerIdentifier: "iCloud.com.YOURNAME.Nodus"
    )?.appendingPathComponent("Documents")
}
```
> ⚠️ This returns nil in Simulator if iCloud is not signed in.
> Always test iCloud features on a real device.

## File Operations to Implement

### Read all notes
```swift
// Pseudocode
func loadNotes() -> [Note] {
    let urls = try FileManager.default
        .contentsOfDirectory(at: containerURL, 
                           includingPropertiesForKeys: [.contentModificationDateKey])
        .filter { $0.pathExtension == "md" }
    return urls.map { Note(url: $0) }
}
```

### Create a note
```swift
// Filename: YYYYMMDDHHmm.md
func createNote() -> Note {
    let timestamp = DateFormatter.noteTimestamp.string(from: Date())
    let filename = "\(timestamp).md"
    let url = containerURL.appendingPathComponent(filename)
    FileManager.default.createFile(atPath: url.path, contents: Data())
    return Note(url: url)
}
```

### Save (update) a note
```swift
func saveNote(_ note: Note) throws {
    try note.body.write(to: note.url, atomically: true, encoding: .utf8)
}
```

### Delete a note
```swift
func deleteNote(_ note: Note) throws {
    try FileManager.default.removeItem(at: note.url)
}
```

### Rename a note
```swift
// Called when user edits the title field
func renameNote(_ note: Note, newTitle: String) throws -> Note {
    let timestamp = note.timestampID  // extract from current filename
    let newFilename = newTitle.isEmpty 
        ? "\(timestamp).md"
        : "\(timestamp) \(newTitle).md"
    let newURL = containerURL.appendingPathComponent(newFilename)
    try FileManager.default.moveItem(at: note.url, to: newURL)
    return Note(url: newURL)
}
```

## Updated Note Model
```swift
struct Note: Identifiable {
    let url: URL
    var body: String
    var createdAt: Date
    var updatedAt: Date

    var id: String { timestampID }
    var filename: String { url.lastPathComponent }

    // "202604271321 Title.md" → "202604271321"
    var timestampID: String {
        String(filename.prefix(12))
    }

    // "202604271321 Title.md" → "Title"
    var title: String {
        let name = url.deletingPathExtension().lastPathComponent
        let afterTimestamp = name.dropFirst(12).trimmingCharacters(in: .whitespaces)
        return afterTimestamp.isEmpty ? filename : afterTimestamp
    }
}
```

## File Change Monitoring
iCloud files can change from outside the app (e.g. The Archive on Mac).
Use `NSMetadataQuery` to monitor changes.

```swift
// Pseudocode — ask Cursor to implement the full version
let query = NSMetadataQuery()
query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
query.predicate = NSPredicate(format: "%K LIKE '*.md'", NSMetadataItemFSNameKey)
// Observe NSMetadataQueryDidUpdateNotification
```
> ⚠️ This is the most complex part of Phase 3.
> Implement it after basic read/write is working.

## Phase 3 Checklist
- [ ] iCloud capability added in Xcode
- [ ] iCloudContainerURL() returns valid URL on device
- [ ] loadNotes() reads real .md files
- [ ] createNote() creates a new timestamped .md file
- [ ] saveNote() writes body to file (auto-save on edit)
- [ ] deleteNote() removes file (with swipe-to-delete in list)
- [ ] renameNote() renames file preserving timestamp ID
- [ ] NSMetadataQuery monitors for external file changes
- [ ] Tested on real device (not just simulator)

## Auto-save Strategy
Do NOT require a "Save" button. Auto-save on:
1. User navigates away from note
2. App goes to background (`scenePhase == .background`)
3. 2-second debounce after last keystroke

## Common Pitfalls
| Pitfall | Solution |
|---------|----------|
| `url(forUbiquityContainerIdentifier:)` returns nil | Test on real device, ensure iCloud is signed in |
| File not appearing in Files.app | Ensure you're writing to `.../Documents/` subdirectory |
| Conflicting edits from Mac | NSMetadataQuery update notification will reload affected notes |
| Simulator iCloud unreliable | Always do final verification on real device |
