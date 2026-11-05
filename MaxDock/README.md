# MaxDock rootless alpha96

Based on the original rootless alpha93, with a third Dock mode: Swipe Loop. Normal and Circular remain separate choices. Swipe Loop keeps icons on a horizontal baseline within the Dock footprint, using perspective yaw, depth translation, scaling and edge fade. Horizontal pans continuously wrap the full icon set, with no first/last endpoint and no icon snapping on release. This is not an upright circular ring or automatic unattended rotation.

Select Settings → MaxDock → Dock Mode → سحب مستمر. Existing rotation-speed and icon-scale controls also adjust the shared carousel renderer. Swipe phase is stored separately from CircularPhase. Mode changes restore the native Dock before building the other presentation. Long press hands editing/drag/drop to the native Dock, as in alpha93; no proxy drag-session forwarding is reintroduced.

Rootless package only, not RootHide. Existing OS compatibility gates retained: iOS16 is the previously tested baseline; other release families remain experimental and require explicit enablement. No fixes for unobserved iOS17.1.1 crashes are claimed.

Tests cover finite geometry, constant vertical baseline, depth transform values, infinite positive/negative wrapping, repeated non-snapping rotations, cancellation, mode switching and native-state restoration, plus existing circular/handoff and preference-load regressions. They use synthetic icons and hidden UIKit windows, not actual SpringBoard icon moves or app launches. No installation or respring is performed automatically. Live behavior after user installation needs confirmation.
