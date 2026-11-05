# MaxDock Xcode CI integration

This repository is also a Sileo/APT repository. MaxDock's source is therefore under `MaxDock/`; existing package indexes and website files are not changed. The active workflow is `.github/workflows/maxdock-build.yml`.

The developer's original PAC checker is retained unchanged (except LF normalization). The original write-up is preserved as `BUILDING-CI-DEVELOPER-ORIGINAL.md`. Its source-at-repository-root and tag-release instructions do not apply to this integration.

## Build and download

Push this branch to GitHub. The push starts **Build MaxDock with Xcode**. Open **Actions**, select the run for this branch, and download `MaxDock-deb-<run number>` after success. A manually dispatched build is available once the workflow is on the repository's default branch. A failed run provides `MaxDock-build-logs-<run number>`.

The workflow uses `macos-15`, Apple's selected Xcode toolchain, Theos, the private-framework-capable iPhoneOS16.5 SDK, both arm64/arm64e and deployment target iOS15. It never installs on a phone or updates the APT package indexes. It does not create a GitHub Release. The workflow token has read-only repository permissions.

Theos, SDK and action references are pinned to the revisions recorded in the workflow. Xcode/compiler versions and build/PAC output are included with the result. Homebrew tool versions and the selected Xcode image can change between hosted runs; this is not a bit-for-bit reproducible build claim.

The package version becomes `2.0.0-alpha100+ci.<run number>` so it can be distinguished from the previous on-device build. Runtime source and settings code remain byte-for-byte alpha100; `MAXDOCK-CI-SOURCE-MANIFEST.json` records original input hashes. The `control` version is changed only inside the runner's build workspace.

## Gate and limits

The developer's checker must pass, and the log must explicitly contain successful checks for both `Harbor.dylib` and `harborprefs.bundle/harborprefs`. Only then is the test package uploaded. SHA256SUMS.txt accompanies it.

This checks the developer's reported unsigned-Objective-C-metadata failure mode. It does not establish that the tweak's features are safe on every supported firmware or that every PAC relocation is correct. The reported successful iOS17.1.2 startup is the developer's result, not a result reproduced by this integration. Feature and modern-device tests remain separate.

References: https://theos.dev/docs/arm64e-deployment and https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
