# Building MaxDock without a Mac (GitHub Actions)

> Repository integration note: source lives under `MaxDock/` in this Sileo repository.
> Use `.github/workflows/maxdock-build.yml` and read `MAXDOCK-CI-SETUP.md` for the
> actual artifact names and branch workflow. Automatic tag releases are not enabled.
> The remaining text is the developer's original diagnosis and proposed setup.

## The iOS 17 crash / Safe Mode reports

Your notes mention unreproduced iOS 17.1.1 crashes and reported Safe Mode with an
unconfirmed cause. We reproduced the problem with the alpha100 package built on-device
(Procursus clang + Theos on iOS 16.7.16) on an iOS 17.1.2 device (Dopamine, ElleKit 1.2):
SpringBoard fails while loading `Harbor.dylib`.

### Root cause: arm64e Objective-C metadata was not PAC-signed

- The on-device build's arm64e Objective-C class metadata carries **no pointer
  authentication**: `isa` / `superclass` / `class_ro` are plain rebases/binds, and
  `__objc_imageinfo` lacks the SignedClassRO flag (`0x40` instead of `0x50`).
- When ElleKit's injector `dlopen`s `Harbor.dylib`, iOS 17's libobjc registers its
  classes (`map_images` → `readClass` → `class_data_bits_t::safe_ro`), authenticates the
  class metadata there, and traps. This happens **before** MaxDock's `%ctor` runs; its hooks
  never ran, and the `Enabled` preference was still off.
- The same, unmodified source built with Apple's Xcode toolchain has signed metadata
  (`auth-rebase` / `auth-bind`, `class_ro` signed with discriminator `0x61F8`, imageinfo
  flags `0x50`). That package loads on iOS 17.1.2 and SpringBoard boots.
- Your iOS 16.7.16 device loaded the unsigned build, which fits the
  "only iOS 17 breaks" reports.
- Caveat: the libobjc disassembly shows the trap is inside `safe_ro`, but the exact
  authentication check that fires was not pinned down. The evidence is that rebuilding the
  same, unmodified source with Xcode makes the problem go away. That swaps the whole
  toolchain, not only the signing, but the trap sits in pointer-authentication code and the
  missing signatures are the difference that matters there.
- The tweak's iOS 17 *behaviour* (with `Enabled` on) is still untested.

**Fix:** build with Apple's toolchain, e.g. with the GitHub Actions workflow below.

### Side note: Safe Mode vs. a black-screen hang

On our test device the crash did not reach Safe Mode: SpringBoard stayed on a black
screen, the device got hot, and no crash log was written. That is a separate bug in
ElleKit's Safe Mode crash handler (it can deadlock when the crash happens inside the
Objective-C runtime). It doesn't change the root cause above, and MaxDock doesn't need
to work around it. Depending on the setup, users of the unsigned build may report either
Safe Mode or a black-screen hang.

## Using the workflow

1. Push this repository to GitHub (public repos get macOS runners for free).
2. Every push builds the package; download it from
   **Actions → the run → Artifacts → MaxDock-deb**.
3. Push a tag like `v2.0.0-alpha101` to also attach the `.deb` to a GitHub Release.

The workflow (`.github/workflows/build.yml`):

- installs `ldid`, GNU `make`, `xz` on a `macos-15` runner,
- clones Theos and only the `iPhoneOS16.5.sdk` from `theos/sdks`
  (needed for the private `Preferences.framework` used by `harborprefs`),
- runs `gmake package FINALPACKAGE=1 TARGET=iphone:clang:16.5:15.0`
  (pinning the SDK; `latest` would select Xcode's SDK and fail to link `harborprefs`),
- runs `.github/scripts/check-ptrauth.sh`, which **fails the build** if any arm64e binary
  with Objective-C classes has unsigned class metadata,
- uploads the `.deb`.

You can run the check on any package yourself (macOS, needs Xcode command-line tools):

```sh
bash .github/scripts/check-ptrauth.sh packages/*.deb
```

On the alpha100 on-device package it reports `FAIL` for both `Harbor.dylib` and
`harborprefs`; on the Xcode build it reports `OK`.

## Notes

- Keep building on-device only if you remove all statically defined Objective-C classes
  (`@interface`/`@implementation`) from the tweak; Logos `%hook` alone is not affected.
  The CI route is much simpler.
- arm64-only builds are not an option: SpringBoard on A12+ devices is arm64e.
- The package ID `com.eswick.harbor16` reuses the original Harbor author's namespace;
  consider your own ID to avoid clashing with eswick's packages.
