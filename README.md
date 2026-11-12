# CogNote iOS

Native iOS version of CogNote (SwiftUI + SwiftData). No login: everything is stored on the device.

- **Requires:** Xcode 16 or newer, iOS 17+.
- **Languages:** English, Portuguese (Brazil), French, Simplified Chinese. The app follows the iPhone's language. Each user can also change it in Settings → CogNote → Language.
- **Strings:** `Cognote/Localizable.xcstrings`, generated from `yiqiji/public/i18n/*.json` and using the same keys.

## Running it

1. Open `Cognote.xcodeproj`.
2. Select the **Cognote** target → **Signing & Capabilities** → choose your Apple ID under *Team*. The free Personal Team is enough.
3. If Xcode says the bundle id is taken, change `dev.akrios.cognote` to something unique.
4. Pick a simulator or your iPhone and press Run.

On a real iPhone with the free account, the install expires after 7 days. Press Run again to reinstall; the data stays.

### On the Mac

The same target runs on the Mac through Mac Catalyst, using the Mac interface style. In the device picker, choose **My Mac**, then press Run. On iPad and Mac, spaces appear in a sidebar next to the content. On iPhone the same screens stack. Shortcuts: ⌘N for a new entry and ⇧⌘N for a new space.

## Structure

| Folder | What it holds |
|---|---|
| `App/` | App entry point, onboarding/home switch, database setup (`Persistence.swift`) |
| `Models/` | `Space`, `SpaceEntry` (the web app's workspace / workspace item), `Tombstone`, and `Store` (create / edit / delete rules) |
| `Insights/` | Port of `server/lib/insights-calc.ts`, computed on device |
| `Views/` | Home, Space, Entry form, Future (watch later), Insights, Onboarding |
| `Design/` | The five themes from `styles.css` (picked in the home "…" menu), formatting, shared components |
| `Export/` | CSV export, plus `APIPayload` for a future upload to the web API |

## Turning on iCloud (once you have a paid account)

The models already follow CloudKit's rules: every field has a default, relationships are optional, and nothing is marked unique. Turning iCloud on takes three steps:

1. In Xcode → target → **Signing & Capabilities** → **+ Capability** → **iCloud**. Tick **CloudKit** and create a container, e.g. `iCloud.dev.akrios.cognote`.
2. Add the **Background Modes** capability and tick **Remote notifications**.
3. In `App/Persistence.swift`, set `iCloudSyncEnabled = true`.

Data that is already on the phone is uploaded the first time the app runs with iCloud on.

## Sending data to the web API later

`APIPayload.build(context:since:)` produces JSON in the same shape as the web app's `WorkspaceModel` and `WorkspaceItemModel`:

- Ids are UUIDs.
- `time` is a `YYYY-MM-DD` string.
- `updatedAt` is included, so you can send only what changed since the last upload.
- `deleted` lists what was removed (from `Tombstone`).

Nothing calls it yet. The plan is an `/api/import` endpoint on the web side, which needs a login there.
