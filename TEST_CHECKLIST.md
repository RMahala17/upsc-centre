# Test checklist

Run `flutter analyze` and `flutter test` first. They must be clean.
Then go through this list on a **real phone** (Android Chrome) and once on a
desktop browser. Tick each box. Anything that fails: note the step.

## A. Install and offline
- [ ] Site opens; splash then app. No red error screen.
- [ ] Wait 10s, turn on airplane mode, reload: app still opens with data.
- [ ] Chrome offers Install; installed app opens full screen without the URL bar.
- [ ] Icon on the home screen is the app icon, not a letter/blank (maskable crop looks fine).
- [ ] Browser/status-bar colour matches the theme (dark vs light).

## B. Appearance
- [ ] Dashboard and More: the sun/moon button shows Light, System, Dark with a tick on the current one.
- [ ] Light: every screen readable; no white-on-white or black-on-black text.
      Check Dashboard, Syllabus, Planner, Timer, Revision, Answers, Tests, PYQ, Notes, Analytics, Backup.
- [ ] Dark: same screens fine.
- [ ] System: change the phone's dark mode switch; the app follows.
- [ ] Close and reopen: the choice is remembered.
- [ ] Charts, progress bars, the running-timer bar look right in both.

## C. Backup
- [ ] Add a few things first (a subject lecture, a task, a test, a note, a CA entry).
- [ ] Backup & Settings -> counts shown match what you added.
- [ ] **Download backup**: file `upsc-backup-YYYY-MM-DD...json` is saved.
- [ ] **Copy as text** works (paste into Notes to confirm it is JSON).
- [ ] The dashboard backup banner disappears after a backup.
- [ ] Change some data (delete a task, add another).
- [ ] **Choose backup file** -> preview shows counts and date -> Restore. Data returns to the backed-up state.
- [ ] **Go back to that data** (Undo last restore) returns the changes made before the restore.
- [ ] **Paste backup text** works the same.
- [ ] Wrong file (a .txt or random JSON): clear error, nothing changed.
- [ ] Cancel in the file picker: nothing happens, no error.
- [ ] Hindi text (notes, answer titles) survives a backup and restore.

## D. CSV export
- [ ] Each of the 8 exports downloads a .csv.
- [ ] Open in Excel / Google Sheets: columns line up; Hindi shows correctly (not ????).
- [ ] An entry starting with `=`, `+`, `-` or `@` shows as text, not a formula.
- [ ] A note with commas, quotes and line breaks stays in one cell.
- [ ] **Download all** gives every file.

## E. Data survives
- [ ] Start the timer, close the tab (or kill the app), reopen: timer still running with correct elapsed time.
- [ ] Reload the page on every tab: no data lost, no blank screen.
- [ ] Back button on phone moves between screens, does not leave the app unexpectedly.
- [ ] **Request protection**: shows Protected or a clear "browser decided" message (either is OK, not a crash).

## F. Feature smoke test (each screen, add + edit + delete)
- [ ] Syllabus: mark lecture done, progress % changes everywhere (Dashboard, Analytics).
- [ ] Planner: add task, complete it, move to another day.
- [ ] Timer: start, pause, stop, session appears in Analytics.
- [ ] Revision: create a cycle, tick items, mark complete.
- [ ] Answers: add, change status.
- [ ] Tests: MCQ score calculated with negative marking; mains test with typed score.
- [ ] PYQ: add, mark status.
- [ ] Current affairs: add item for UP / National / International; revision gaps appear at 7, 21, 60 days.
- [ ] Dashboard: set exam dates; countdown correct; daily goal ring updates.
- [ ] Analytics: three tabs load with real numbers; empty state OK on a fresh browser.
- [ ] Fresh browser profile (empty data): no screen crashes.

## G. Edge cases
- [ ] Very long title (200+ characters) does not break the layout.
- [ ] Phone in landscape and a narrow 320px width: no overflow stripes.
- [ ] Phone text size set to Large in system settings: still usable.
- [ ] Date change at midnight: today's tasks and streak roll over correctly.
