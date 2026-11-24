# MacBox security

## Supported versions

MacBox is experimental. Security fixes land on `main`; there are no supported releases yet.

## Reporting a problem

Please report security problems privately through
[MacBox's GitHub security advisories](https://github.com/AyhanSh/MacBox/security/advisories/new),
rather than opening a public issue. MacBox reports are handled in this repository;
upstream XCL has its own maintainers and reporting policy.

Say what the problem is, how to reproduce it, and which commit you tested. A small test case helps
more than a long write-up.

Don't attach game files, dumps or anything else from a game package.

## What counts

MacBox runs XCL and a game's code with the same rights as your user account. It is not a sandbox,
and a game run through it is no more contained than any other program you start yourself.

Things worth reporting:

- a write that gets past the overlay and changes the game folder or anything outside the title's
  data folder
- a console path (`GAME:`, `G:`, `S:\`, `T:\` …) that resolves to somewhere it shouldn't
- a crafted game file (shader pack, RPF archive, texture, PE image) that makes XCL itself crash or
  run code it shouldn't
- `report.json` or the logs leaking something they shouldn't, like paths or names outside the game

Bugs that only crash the game, or need online services XCL doesn't provide, are normal issues.

## No warranty

MacBox retains XCL's GPL-2.0-only license and comes with no warranty (see `LICENSE`). Reports are
handled when someone has time; there is no fixed response time.
