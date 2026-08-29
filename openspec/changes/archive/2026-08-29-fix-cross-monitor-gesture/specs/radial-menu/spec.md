## ADDED Requirements

### Requirement: Menu appears on the monitor holding the pointer

The menu SHALL be drawn on the monitor containing the pointer at the moment the shortcut is pressed,
so that the gesture is made on the screen the user is looking at. When the pointer is on no monitor,
the menu SHALL be drawn on the monitor holding the target window.

#### Scenario: Pointer and focused window on the same monitor

- **WHEN** the shortcut is pressed with the pointer on the same monitor as the focused window
- **THEN** the menu is drawn on that monitor

#### Scenario: Pointer on a monitor other than the focused window's

- **WHEN** the shortcut is pressed with the focused window on one monitor and the pointer on another
- **THEN** the menu is drawn on the monitor holding the pointer
- **AND** it is drawn around the pointer rather than against an edge of the window's monitor

#### Scenario: Pointer on no monitor

- **WHEN** the shortcut is pressed while the pointer is not on any monitor
- **THEN** the menu is drawn on the monitor holding the target window

### Requirement: The gesture's monitor is fixed when the menu opens

The system SHALL choose the gesture's monitor once, when the menu is raised, and SHALL NOT
reconsider it for the rest of the gesture. Pointer movement during the gesture SHALL change only the
selected sector.

#### Scenario: Pointer crosses onto another monitor during the gesture

- **WHEN** the pointer moves onto a different monitor while the menu is up
- **THEN** the menu stays on the monitor it was raised on
- **AND** releasing the shortcut acts on the monitor the menu was raised on

#### Scenario: Gesture toward an adjoining monitor

- **WHEN** the gesture begins near the boundary between two monitors and the pointer is moved across
  it
- **THEN** the sector selected is the one matching the direction of movement
- **AND** the monitor acted upon is unchanged by the crossing

## REMOVED Requirements

### Requirement: Menu appears on the monitor of the target window

**Reason**: The menu followed the target window, so a gesture made with the pointer on another
monitor was drawn on the window's monitor and clamped against the edge nearest the pointer. This
placed the menu somewhere the user was not looking, and left no gesture able to move a window
between monitors.

**Migration**: Replaced by "Menu appears on the monitor holding the pointer". Where the pointer and
the target window are on the same monitor — the ordinary case — the menu is drawn exactly where it
was before, so no user-visible behaviour changes on a single-monitor desktop.
