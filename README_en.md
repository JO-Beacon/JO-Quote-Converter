# JO-Quote-Converter

> 简体中文: [README.md](README.md)

JO-Quote-Converter is a local Flutter text tool that converts English straight quotes into Chinese curly quotes. It targets Windows and Android. Text processing and draft saving happen locally on the device; only manual update checks access GitHub Releases.

Author: GitHub [JO-Beacon](https://github.com/JO-Beacon)

## Features

- Converts English double quotes `"..."` into Chinese double quotes `“...”`
- Converts English single quotes `'...'` into Chinese single quotes `‘...’`
- Optional heuristic detection that tries to identify ambiguous apostrophes such as contractions, possessives, length units, and decade abbreviations; the result is not guaranteed for every ambiguous text
- Optional mechanical pairing mode: with heuristics off, single and double quotes are paired strictly in left, right, left, right order
- Avoids re-converting Chinese curly quotes that are already present
- Optional Markdown exclusion that keeps original quotes in fenced code blocks and inline code
- Copy converted result and clear text
- Follow-system, light, and dark appearance modes
- Six color themes: red, yellow, green, blue, purple, and gray; gray is the default
- Bundled Source Han Sans Simplified Chinese with Regular, Medium, and Bold weights
- Real-time saving of source text, converted result, Markdown exclusion, and heuristic settings, restored after closing and reopening
- Each conversion stores source text, converted result, and time in SQLite history, shown newest first
- Search history by source text or converted result
- View full history details, copy source or result separately, and see total entry count and SQLite storage size
- Restore source text and converted result from history into the workspace, with confirmation before overwriting a non-empty workspace
- Delete individual history entries with confirmation
- Clear all history entries in bulk with confirmation
- Export workspace, settings, and history to a compressed `.joquoteconverter` archive and import it between Windows and Android
- Validate archive integrity before import, then choose smart merge or full overwrite; smart merge keeps a non-empty workspace and current settings, and merges history without duplicates
- Windows installed builds associate `.joquoteconverter` archives so double-clicking an archive opens the app with import-mode selection
- Before import completes, automatically create a pre-import backup in the app's local data directory; restore it if the import fails
- Manage automatic backups in Settings: view time, version, history count, and file size; restore, delete individually, or clear all
- About page supports manual checking for the latest GitHub Release and opens the release page when an update is available
- Settings use categorized lists for language, appearance, behavior, keyboard shortcuts, data and archives, and about; UI language supports Simplified Chinese and English, defaulting to Simplified Chinese
- Windows supports `Ctrl+Enter` to convert the current text, and keyboard shortcuts can be disabled from Shortcut Settings
- Desktop wide-screen workspace uses a left-right split; narrow screens automatically switch to a top-bottom layout

## Usage

1. Enter or paste text into the “Source” area.
2. Open “Settings” from the top-right corner and configure “Exclude Markdown code” and “Heuristic detection” as needed. The two options are independent.
3. Tap “Convert” and view the result on the right or below.
4. Tap the copy button to copy the converted result.

On Windows, press `Ctrl+Enter` to convert; disable keyboard shortcuts in Settings if they are not needed. The history screen supports searching, restoring, deleting individual entries, and clearing all entries.

In “Settings → Data & Archives”, export or import `.joquoteconverter` files. On Android, exporting opens the system file-save UI to choose a location. In the Windows installed build, double-clicking a `.joquoteconverter` file also opens the app with the same import-mode choices. Archives use ZIP Deflate compression, contain the workspace, settings, and history, and use SHA-256 to verify content. Archives are not encrypted, so their contents can be extracted and read; treat them as ordinary data backup files and keep them safe.

Drafts are saved automatically as text changes. The app also writes the current state once when the window closes normally, the app moves to the background, or the app exits.

## Data & Privacy

The app does not require an account, does not upload text, and has no backend service. Manual update checks only read public GitHub Release information and do not send workspace text. Conversion history is stored locally in SQLite in the device's app data directory. Current drafts and related options are stored locally through Flutter `shared_preferences`.

Pre-import automatic backups are stored locally in the app support directory under `backups` and are never uploaded. View, restore, or clean them in “Settings → Data & Archives → Automatic Backups”. Restoring an automatic backup overwrites the current workspace, settings, and all history, and makes another backup of the current data before restoring. Smart merge keeps a non-empty workspace and current settings; for history, it keeps existing entries and skips entries whose source, result, and time are exactly the same. Full overwrite replaces the workspace, settings, and all history with the archive contents.

On Windows, when the new data directory is first used, drafts, settings, and history from the old `com.localtools` directory are migrated once to the `JO-Beacon` directory. Migration does not delete old data.

## Development

The project is developed with Flutter 3.44.1 and Dart 3.12.1.

```powershell
flutter pub get
flutter run -d windows
```

Run checks:

```powershell
dart analyze
flutter test
```

Some Windows native build tools have limited support for project paths containing non-ASCII characters. If a build fails, move the project to an ASCII-only path and build again.

## Project Structure

```text
lib/
  main.dart             App UI, theme, and draft restoration
  archive_service.dart  Archive compression, verification, import/export, and automatic backups
  quote_converter.dart  Quote conversion and Markdown code exclusion
  draft_store.dart      Local draft storage
  history_store.dart    SQLite history storage and legacy data migration
  update_service.dart   GitHub Release update checks
assets/
  fonts/                Source Han Sans font files
  images/               App icon resources
  licenses/             Third-party font licenses
test/                   Conversion logic and UI tests
installer/              Windows Inno Setup installer scripts
```

## Feedback & Contributions

This project does not accept Pull Requests.

To report a bug, compatibility problem, or feature request, submit an Issue. Include the original text, expected result, actual result, and platform whenever possible to help reproduce and investigate.

Report security vulnerabilities privately according to the [Security Policy](SECURITY.md). Do not disclose details of unfixed vulnerabilities in public Issues.

## License

The project source code is licensed under the [Apache License 2.0](LICENSE).

The bundled Source Han Sans font is provided by Adobe and licensed under the [SIL Open Font License 1.1](assets/licenses/SourceHanSans-OFL-1.1.txt). Third-party dependencies remain under their respective licenses; the Apache License 2.0 does not override those third-party contents.
