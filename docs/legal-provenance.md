# Legal sources and provenance review

Reviewed on 25 November 2026 with Codex (GPT-6). These notes record source material
and open verification items; they are not a legal opinion or a complete audit of
the repository, dependency graph, binaries or game-data acquisition.

## Reference projects

| Reference | Relevant provisions | Treatment in MacBox |
|---|---|---|
| [XCL license](https://github.com/xcl-dev/xcl/blob/main/LICENSE), [contribution rules](https://github.com/xcl-dev/xcl/blob/main/CONTRIBUTING.md) and [security policy](https://github.com/xcl-dev/xcl/blob/main/SECURITY.md) | GPLv2 terms, provenance requirements, exclusion of game material, experimental execution without sandbox guarantees. | Keep MacBox's GPL-2.0-only license; explain scope and risks in an original notice. |
| [VIctory-macOS legal notice](https://github.com/pragyaangaur/VIctory-macOS#legal) and [contribution rules](https://github.com/pragyaangaur/VIctory-macOS/blob/main/CONTRIBUTING.md) | Independent-project attribution, user-supplied game data, separately obtained proprietary components. | Use corresponding principles with MacBox's actual setup; do not copy another project's affiliation or compatibility claims. |
| [VIctory package metadata](https://github.com/Marvisak/VIctory/blob/main/Cargo.toml) and [macOS fork metadata](https://github.com/pragyaangaur/VIctory-macOS/blob/main/Cargo.toml) | GPL-3.0-or-later, unlike MacBox's GPL-2.0-only. | The reference project's license is not a replacement for MacBox's license or a general import permission. |
| [VIctory asset policy](https://github.com/Marvisak/VIctory/blob/main/docs/asset-policy.md) | Synthetic fixtures and local game-data storage, with an explicit BCPack-table exception. | Keep submission rules separate from software-license rights; investigate the exception below. |

VIctory-macOS also has a [test-fleet legal policy](https://github.com/pragyaangaur/VIctory-macOS/blob/main/docs/fleet-legal.md).
Its fleet-specific assurances do not establish the legality of MacBox or its use
with game packages. Neither project's legal pages establish immunity from claims.

The [GNU GPLv2 text](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
is the controlling license reference. Its sections 0 and 6 do not support adding
research-only, noncommercial or no-redistribution conditions to GPL permissions.
The [GNU compatibility FAQ](https://www.gnu.org/licenses/gpl-faq.html#v2v3Compatibility)
explains why GPL-2.0-only and GPLv3 code cannot ordinarily be combined for distribution
without another sufficient permission. The new [terms notice](../TERMS_OF_USE.md)
does not change the license.

## BCPack: recorded permission and an unresolved table question

An in-progress MacBox BCPack integration uses `crates/xcl/src/hle/bcpack/victory.rs`,
generated `tables.rs`, and `scripts/gen_bcpack_victory_tables.py`. This documentation
update records the review; it does not publish that runtime integration.

1. **Recorded decoder permission.** XCL maintainer `ivall` states that VIctory's
   author allowed use under GPL-2.0-only in
   [PR #905's comment](https://github.com/xcl-dev/xcl/pull/905#issuecomment-7129071161).
   [Provenance commit `8add9a3`](https://github.com/xcl-dev/xcl/commit/8add9a327f60dfe34fcd3a7ea16368c0ec5a7a22)
   records that permission. This review located the maintainer's record, not the
   original author's grant text and complete scope. It is not blanket permission
   to import other VIctory code.
2. **Tables are a separate question.** VIctory's asset policy expressly excludes
   `bcpack-tables.bin` from its repository license and says the tables are not its
   authors' work. Converting that file into Rust constants does not establish a
   license for the underlying material.
3. **Partial provenance is not complete clearance.**
   [XCL's attribution record](https://github.com/xcl-dev/xcl/blob/main/THIRD_PARTY.md)
   identifies the 128 rANS models with Microsoft's MIT-licensed
   [silicon-rans sample](https://github.com/microsoft/silicon-rans).
   That does not establish permission for every dictionary, index or control table.

Before distributing the imported table data, record a sufficient rights basis for
each component and confirm the scope of any separate grant, including downstream
redistribution. Retain source revisions, notices and the permission evidence.
If that cannot be established, resolve the affected material with the relevant
rights holders and qualified counsel, or exclude it from the distribution.
This review does not authorize the table data merely because an upstream project
ships it. A disclaimer cannot supply missing rights.

## Release review

For each release, check license notices and attribution against the actual files
and dependencies shipped, provide the source and build materials the GPL requires,
and verify any rights needed to bundle external runtimes. Review the release
archive and published diagnostics for proprietary content and credentials.
Document unresolved provenance separately from test or compatibility results.
This documentation change does not perform or certify those release checks.
