# Normal-mode animation styles — alpha100

Settings: MaxDock > Normal Mode Animation > Choose Animation. Choose Classic, Scale Only, Fan, Elastic Wave, or 3D Pop. Animation Strength ranges from 0 to 1.5; 1 is the default. This selection does not change DockMode. Classic remains the default when no selection exists.

Classic preserves the prior affine formula at default strength. Scale Only suppresses lift. Fan adds signed tilt and separation. Elastic Wave uses slower frame-rate-adjusted focus tracking and a softer spring return. 3D Pop adds bounded perspective, forward depth and side tilt. Native icon transforms are captured/restored in full 3D so the new effect does not leave a perspective transform behind after the gesture.

The existing animation duration, magnification and lift controls remain applicable where relevant. Circular and Swipe Loop retain their own renderers.

Validation: isolated UIKit/math tests and preference-bundle load on iOS16.7.16; no actual Dock gesture/launch test or automatic installation performed. The unresolved startup freeze on other devices is not fixed or reclassified by this feature update. Per-OS experimental opt-in remains unchanged.
