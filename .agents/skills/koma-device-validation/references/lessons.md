# Device validation lessons

Append one short entry after a reusable failure. Keep incident evidence in the owning work order; this file records only the decision rule that prevents repetition.

## 2026-11-11 - Source-list search was ignored

Failure: A real-device same-title download check was attempted by repeatedly scrolling a 96-source list and taking screenshots. The process used nearly one hundred protocol invocations before the source row was opened.

Rule: Before any long-list navigation, find and use the list's search or filter entry. If repeated scrolling is unavoidable, put the scroll-and-detect loop in one bounded protocol rather than launching a new script per swipe.

## 2026-11-11 - A prerequisite dialog was dismissed by navigation

Failure: After tapping a chapter download action, the app showed "下载此作品需要先加入书架" with a confirmation action. The next probe opened the downloads page, dismissing the dialog; the task never entered the queue. This happened twice.

Rule: After an action that can produce a dialog, inspect the resulting screen before leaving it. Handle the exact prerequisite or confirmation action. Do not force-stop or switch pages while a transient dialog is pending.

## 2026-11-11 - Search scopes were treated as interchangeable

Failure: A source-scope search menu was retried repeatedly while the active scope remained the bookshelf. A later source-detail search succeeded, but finding the source itself still used manual scrolling.

Rule: Name the scope explicitly before searching: source-list search, source-detail work search, or library/global search. Do not retry the same no-op control; change the route only after verifying the scope.

## 2026-11-11 - Virtual storage URI was probed with shell `ls`

Failure: `ls /storage/Users/currentUser/Download/...` returned "No such file or directory" even though the app content root was valid. The path was a document URI view, not a plain filesystem path.

Rule: Verify downloads through the file manager or app storage API. Do not infer deletion or absence from a raw shell path for a document URI.

## 2026-11-11 - Registry fields were probed with repeated guesses

Failure: The source registry was read with a sequence of different `grep` patterns because its nesting and field names were not understood first.

Rule: Read one complete structural sample or schema before selecting fields. Parse once, then extract the needed values in one bounded command.

## 2026-11-12 - A hidden navigation tab consumed a shelf-card tap

Failure: A layout retained the text bounds of a mostly hidden navigation tab. Tapping its reported position opened the shelf item underneath instead of navigating.

Rule: Before tapping a floating or auto-hidden control, verify that its entire hit area is visible and unobstructed in the current screenshot. Reveal the control first; a layout node alone does not prove its hit area is usable.
