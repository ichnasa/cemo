# Cemo

Save links and notes into conversations, star and pin them, and set reminders.
Flutter app for iOS and Android, built from the Cemo design canvas.

## First run

The platform folders (`android/`, `ios/`) are not included. Generate them once,
from inside this folder:

```
flutter create --platforms=android,ios --org com.example .
flutter pub get
flutter run
```

`flutter create` keeps the existing `lib/`, `pubspec.yaml` and `test/` files.
Change `com.example` to your own reverse-domain name before publishing.
Building for iOS needs a Mac with Xcode; Android builds work on Linux, Windows and macOS.

## What works

- Onboarding (8 screens) -> Join / Sign up / Log in -> the app
- Home: conversation list with All / Pinned / Archived tabs, a labelled
  "+ Category" button, and a round New note button at the bottom right
- Press and hold a category: the top bar switches to pin, archive and delete.
  Delete archives after a confirmation; permanent delete is in Archived.
- Category names must be unique (ignoring case)
- Conversation: text, link and checklist notes; All notes / Starred tabs;
  reminder strip that jumps to the note; composer
- Press and hold a note: the top bar switches to remind, star, copy, forward
  and delete, with multi-select. Forward copies the note to another category.
- Reminder sheet: date and time, with a 2-second Undo message
- Reminders tab: Upcoming / Overdue / Done. Ticking a reminder strikes it
  through and fades it into Done. Press and hold for multi-select (mark done, delete).
- New note, new category, search with highlighted matches
- Profile: appearance (system, light, dark), feedback, replay onboarding, log out
- Light and dark themes from the Foundations colours

## Saved on the device

Everything is saved in the app's documents folder and restored at start-up:
`cemo.json` (categories, notes, reminders, settings) and `category_icons/`
(copies of photos used as category icons). The first run starts with sample
content; delete the app's data to start empty.

Also in this version: tapping a link opens it; tap the conversation header to
edit its name, colour, symbol or photo; the three-dot menu has Search, Media
links and docs, Clear conversation and Export notes (JSON).

## Photos, videos and documents

The camera button in the composer adds a photo or video (camera or photo
library, several at once from the library) or a document. Photos and videos get
a preview with an optional caption. Every file is copied into `attachments/` in
the app's storage, so notes keep working if the original is deleted. Tap a
photo or video to view or play it; tap a document to open it in another app.
The Media and Docs tabs list them per conversation. Forwarding copies the file;
deleting a note deletes its copy.

iOS needs these keys in `ios/Runner/Info.plist`: `NSCameraUsageDescription`,
`NSMicrophoneUsageDescription`, `NSPhotoLibraryUsageDescription`.

## Not built yet

- Accounts: the sign-up and log-in buttons just let you in. Connect a backend
  where the TODO comments are in `lib/screens/auth.dart`.
- Notifications: reminders are stored but nothing fires. Add `flutter_local_notifications`.
- Photo and video editing (draw, text, emoji, crop; trim and mute): next phase.
- An in-app camera with a strip of recent photos. For now the camera button
  opens a short menu, then the phone's own camera or photo picker.
- Video thumbnails: videos show as a dark tile with a play button.
- Saving from the Share Sheet (`receive_sharing_intent`, plus an iOS Share Extension).
- Home Screen widget (`home_widget`, with the widget layout written natively).
- Heroicons: the app uses Flutter's built-in Material icons for now.
- Link previews: a pasted link shows its address, not the page title or image.
- Web: storage uses files, so the app targets iOS and Android only.

## Layout

```
lib/main.dart              app entry, routing between onboarding / account / app
lib/theme.dart             colours and text styles
lib/models.dart            Note, Category, AppState (all data and actions)
lib/storage.dart           files kept on the device
lib/attachments.dart       photos, videos, documents: pick, preview, view
lib/widgets.dart           shared widgets (avatar, pill button, tabs, Memo image)
lib/sheets.dart            bottom sheets: reminder, note actions, new note, new category
lib/screens/               onboarding, auth, home (4 tabs), category, feedback
assets/memo/               the 16 Memo illustrations
```
