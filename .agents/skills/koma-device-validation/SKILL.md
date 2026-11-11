---
name: koma-device-validation
description: Use for Koma HarmonyOS device UI, source navigation, download acceptance, or multi-source verification on real devices. Enforces search-first navigation, one bounded protocol per user journey, and decisive dialog evidence before any further device action.
---

# Koma Device Validation

This skill adds route-selection and stop rules to the repository's existing device gates. Follow the applicable `AGENTS.md` instructions and the HarmonyOS device skills first.

## Search before scrolling

Before touching a long list, inspect the page and source for a search, filter, or direct-route entry. Use the search entry first. A long list is not a reason to start blind swipes.

Keep these scopes distinct and say which one is in use:

- source-list search: finding a source package
- source-detail search: finding a work inside one source
- library/global search: finding a work across installed or enabled sources

Do not replace one scope with another just because it is nearby.

## One journey, one protocol

Put a complete user path in one checked device manifest or one bounded protocol invocation. If the path needs repeated scrolling, loop inside that protocol until the target text appears; do not execute one script per swipe or one script per tap.

Keep the session alive across the path. A new process invocation for every small step is not evidence of progress and makes transient UI state easy to lose.

## Stop rules

Stop changing coordinates after two identical no-op results. Inspect the current layout, window stack, dialog, and the relevant implementation before another action.

Never use force-stop, restart, or page switching to "refresh" a screen while a sheet, menu, dialog, or unsaved form is present. It destroys the state that must be acted on.

After a click that should open a menu, sheet, or confirmation dialog, capture the resulting layout or screenshot before any other navigation. A successful `uiInput` result proves injection only, not a state transition.

When a dialog asks for a prerequisite such as adding a work to the shelf before downloading, handle that exact confirmation. Do not leave the dialog and later treat the missing task as a source failure.

## Storage and evidence

Do not use `ls` on a document URI such as `/storage/Users/currentUser/...` to decide that a file is missing. Use the user-visible file manager, the app's storage API, or a checked content-root probe.

For multi-source or download acceptance, prove all relevant layers: the task queue, the work directory, the chapter directory, at least one page asset, the reader entry, and the cold-start result. A folder name or an injected tap is not completion evidence.

Do not claim acceptance while the decisive state is unknown. Report the failed state and the exact unverified layer instead.

## Accumulating failures

When a new navigation, dialog, or device-protocol failure teaches a reusable rule, append a short entry to [references/lessons.md](references/lessons.md). Keep the root skill focused on decision rules; put dated incident details in that reference.
