# Stage 9: Home screen redesign (matches the new design)

Based on the other app's Home screen. Everything shows YOUR real data; nothing
is hard-coded (the other app had fixed numbers like "Day 142 streak").

## What changed
* Header: logo badge, "UPSC Command Centre", exam label (e.g. "UPSC 2027", taken
  from the exam dates you set on the dashboard) and today's date.
* "Install app" button in the header (web only, hidden once installed). If the
  browser has no install prompt it opens a help popup for Android and iPhone.
  The same popup is used by Backup & Settings -> Install app.
* Prep overview ring (GS + Anthropology lectures) with the GS and Anthro split.
* Three summary cards: GS syllabus, Anthropology, Revision & PYQ.
* "My next target": first unfinished planner task for today, with Start now
  (starts the timer for that task) and a tick button.
* Weekly study hours: Monday to Sunday bars, today highlighted.
* Below that, the existing cards stay: exam countdown, today's goal and streak,
  today's plan, revision, needs attention, quick links.
* Removed from Home: the old "Syllabus progress" and "Last 7 days" cards (the
  ring, summary cards and weekly bars replace them; full detail is in Analytics).

## Not run here
No Flutter SDK in the build sandbox: run `flutter analyze` and `flutter test`.
New tests: test/home_logic_test.dart.

## Files
New: lib/core/widgets/ring_progress.dart, lib/core/widgets/install_guide.dart,
lib/features/dashboard/home_logic.dart, lib/features/dashboard/home_widgets.dart,
test/home_logic_test.dart
Changed: lib/features/dashboard/dashboard_screen.dart,
lib/features/backup/backup_screen.dart, lib/core/platform/platform_stub.dart,
lib/core/platform/platform_web.dart
