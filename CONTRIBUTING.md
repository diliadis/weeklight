# Contributing to Weeklight

Thanks for helping improve Weeklight. Keep changes focused, testable, and
aligned with native macOS conventions.

## Development setup

You need macOS 14 or newer and Xcode 26, or another Apple toolchain that
supports Swift 6.2.

After cloning and entering the repository, run:

```bash
swift test
./Scripts/verify.sh
```

Open `Package.swift` in Xcode for interactive development. To package and run
the app from Terminal:

```bash
./Scripts/build-app.sh
open dist/Weeklight.app
```

## Making a change

1. Create a branch from `main`.
2. Keep business rules in `Domain` or `AppModel`, not in SwiftUI views.
3. Add or update a regression test for behavior changes.
4. Keep accessibility labels and native light/dark appearances intact.
5. Update `CHANGELOG.md` when the change is user-visible.
6. Open a pull request using the repository template.

Persisted schema changes must update the model version identifier and include a
migration strategy. Historical weekly allocations must never be rewritten when
a project's default allocation changes.

## Before opening a pull request

Run all checks locally:

```bash
swift test
./Scripts/verify.sh
./Scripts/build-app.sh
```

Then manually verify affected dashboard and menu-bar flows in both light and
dark mode. If the change affects a running timer, verify relaunch recovery as
well.

## Reporting bugs

Use the bug report form and include:

- macOS and Weeklight versions
- clear reproduction steps
- expected and actual behavior
- screenshots or logs with private project information removed

Do not disclose security vulnerabilities in a public issue. Follow
[SECURITY.md](SECURITY.md) instead. Participation is governed by the
[Code of Conduct](CODE_OF_CONDUCT.md).
