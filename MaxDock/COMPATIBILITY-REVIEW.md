# MaxDock alpha99 compatibility review

Scope: eight Dock/icon classes; current iOS16.7.16 runtime plus published sample headers for iOS17/18/26. This does not cover every point release or prove device compatibility.

## Evidence and changes

- iOS16.7.16: extracted method names and type encodings from the connected device, without icon content or app identifiers. See HEADER-BASELINE16.json.
- iOS17: source is MTACS iOS17.0.3 runtime dump. iOS18 and iOS26 repositories do not establish an exact point release; retain that uncertainty.
- SBDockView in the iOS26 dump stores _glassView. The iOS18 dump stores _backgroundView and _accessibilityBackgroundView. The code now discovers those through validated object-return getters/object ivars and never writes these ivars.
- The getDockViewMetrics: structure declaration differs across dumps. MaxDock does not call that method, so no guessed replacement was added.
- Some methods disappear from a class declaration while remaining inherited. Existing runtime method-signature gates remain necessary; absence in a dumped header is not proof of removal.
- Zero-argument private object getters now reject scalar, structure and block returns before calling objc_msgSend. This addresses ABI mismatch risks, not a confirmed crash stack.
- Arabic text was damaged by a previous encoding conversion. Reversed that conversion, kept UTF8 explicit, and verified Arabic/Glass labels in an isolated preference-bundle test.

## Sources

- https://github.com/MTACS/iOS-17-Runtime-Headers
- https://github.com/qingralf/iOS18-Runtime-Headers
- https://github.com/qingralf/iOS26-Runtime-Headers
- HEADER-SOURCES.json contains requested URLs and fetch status. The 16 remote fetches failed; the live 16.7.16 extraction is used instead.

## Validation and limits

Package and isolated UIKit tests built on iOS16.7.16, arm64 and arm64e binaries. No automatic installation, respring, real app movement or live crash reproduction. iOS15/17/18/26 remain experimental with explicit per-OS opt-in. Safe Mode cause remains unconfirmed. All three modes and glass remain in the package.
