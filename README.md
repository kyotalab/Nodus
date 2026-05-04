# Nodus

> Plain text, connected thinking

A minimal Zettelkasten note-taking app for iOS, inspired by [The Archive](https://zettelkasten.de/the-archive/) (macOS).

---

## Overview

Nodus is built around the core cycle of Zettelkasten as conceived by Niklas Luhmann — not just a note repository, but a thinking and writing system.

```
Write  →  Link  →  Think  →  Output  →  Write again
  ↑_____________________________________________↓
```

Notes are plain Markdown files stored in iCloud Drive. No proprietary format. No lock-in. Compatible with The Archive, Zettlr, iA Writer, or any Markdown editor.

**Nodus** is Latin for "knot" or "node" — a point where things connect.

---

## Features

- **Plain text, always** — Notes are `.md` files stored in iCloud Drive. You own them completely.
- **Wiki links** — Link notes with `[[timestamp]]` syntax. Links survive title renames because they reference the ID, not the title.
- **Fast full-text search** — Space-separated AND search across filenames and note bodies.
- **Edit / Preview toggle** — Monospaced editor for writing, minimal Markdown preview for reading.
- **Keyboard toolbar** — One-tap insertion of `#`, `**`, `*`, `>`, `[[`, and `Tab`.
- **Flexible sorting** — Sort by updated date, created date, title, backlink count, or random.
- **iPhone & iPad** — Single codebase, automatic layout adaptation via `NavigationSplitView`.
- **Works with The Archive** — Select the same iCloud Drive folder on first launch.

---

## Requirements

| Item | Detail |
|------|--------|
| Platform | iOS 17+ |
| Device | iPhone / iPad |
| iCloud | Required for sync |
| Compatible editors | The Archive, Zettlr, iA Writer, Obsidian, any `.md` editor |

---

## File Format

```
YYYYMMDDHHmm Title.md

Examples:
202604271321.md                     ← ID only (just created)
202604271321 Structured contexts.md ← ID + title (renamed later)
```

The 12-digit timestamp prefix is the note's permanent ID. Renaming the title never breaks `[[wiki links]]`.

---

## Wiki Links

```markdown
See also [[202604271321]] for more context.
```

Links are resolved by partial filename match — the first note whose filename contains the ID string. This means links survive title renames.

---

## Architecture

```
Nodus/
├── App/
│   └── NodusApp.swift              ← @main entry point
├── Models/
│   └── Note.swift                  ← Note data model
├── Views/
│   ├── ContentView.swift           ← NavigationSplitView root
│   ├── NoteListView.swift          ← Search bar + note list
│   ├── NoteDetailView.swift        ← Editor + preview toggle
│   └── EmptySelectionView.swift    ← iPad: no note selected state
├── ViewModels/
│   └── NoteStore.swift             ← State management + iCloud I/O
├── Core/                           ← Pure logic (unit tested)
│   ├── SearchEngine.swift          ← AND search logic
│   ├── LinkResolver.swift          ← [[ID]] resolution
│   └── NoteFilenameParser.swift    ← Timestamp/title parsing
└── Utilities/
    └── DateFormatter+Note.swift    ← YYYYMMDDHHmm helpers
```

### Key Design Decisions

**Storage**: iCloud Drive ubiquity container (not CloudKit). Notes are stored in a user-selected folder, visible in Files.app and compatible with desktop Markdown editors.

**Navigation**: `NavigationSplitView` with explicit `horizontalSizeClass` branching — `NavigationStack` + `NavigationLink` for iPhone, `List(selection:)` for iPad.

**Note ID**: 12-digit timestamp (`YYYYMMDDHHmm`) as permanent identifier. Collision-free in normal use. Wiki links use partial filename match for resilience against title renames.

**Testing**: Pinpoint testing only — `SearchEngine`, `LinkResolver`, and `NoteFilenameParser` are covered by unit tests. SwiftUI views and iCloud I/O are not tested.

---

## Development Setup

### Requirements

| Tool | Version |
|------|---------|
| Xcode | 26.3+ |
| macOS | Sequoia 15.6+ |
| Cursor | Latest |

### Getting Started

```bash
git clone https://github.com/YOURNAME/Nodus.git
cd Nodus
open Nodus.xcodeproj
```

Build and run with `⌘R` in Xcode.

> ⚠️ iCloud features require a real device. The iOS Simulator has unreliable iCloud support.

### Cursor Rules

This project uses [Cursor](https://cursor.com) for AI-assisted development. Rules files are located in `.cursor/rules/`:

| File | Active During |
|------|--------------|
| `00_project.md` | Always |
| `01_foundation.md` | PHASE 1–2 |
| `02_icloud.md` | PHASE 3 |
| `03_core.md` | PHASE 4 |
| `04_polish.md` | PHASE 5 |
| `05_appstore.md` | PHASE 6 |

---

## Development Phases

| Phase | Status | Description |
|-------|--------|-------------|
| 1–2: Foundation | ✅ Complete | Project setup, NavigationSplitView skeleton, dummy data |
| 3: iCloud | 🔄 In Progress | Real file I/O, folder selection, NSMetadataQuery sync |
| 4: Core Features | ⏳ Planned | Full-text search, wiki links, editor, keyboard toolbar |
| 5: Polish | ⏳ Planned | Auto-save, empty states, accessibility, iPad shortcuts |
| 6: App Store | ⏳ Planned | TestFlight, screenshots, submission |

---

## License

TBD

---

*Nodus — Plain text, connected thinking*