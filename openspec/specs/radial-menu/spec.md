## Purpose

Lets a user pick a screen region by gesturing in a direction rather than aiming at a target: a
shortcut raises a radial menu, pointer movement away from the gesture origin selects a sector, and
releasing the shortcut commits that choice.

## Requirements

### Requirement: Shortcut raises the radial menu

The system SHALL raise the radial menu when the user presses a user-configurable shortcut, and the
menu SHALL remain visible for as long as the shortcut's modifier keys are held.

#### Scenario: Shortcut pressed while a window is focused

- **WHEN** the user presses the configured shortcut and a snappable window is focused
- **THEN** the radial menu becomes visible
- **AND** it remains visible while the modifier keys stay held

#### Scenario: Shortcut pressed with no snappable window

- **WHEN** the user presses the configured shortcut and no snappable window is focused
- **THEN** the radial menu is not raised
- **AND** no window is moved or resized

#### Scenario: Shortcut is held down

- **WHEN** the user holds the shortcut without releasing it
- **THEN** the menu is raised exactly once
- **AND** key auto-repeat does not raise it again or restart the gesture

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

### Requirement: Pointer direction selects a sector

While the menu is up, the system SHALL derive the selected sector from the direction of the pointer
relative to the pointer position recorded when the menu was raised. Selection SHALL depend on
direction, not on the pointer landing inside any drawn shape.

#### Scenario: Pointer moved toward a sector

- **WHEN** the user moves the pointer away from the gesture origin toward a sector
- **THEN** that sector becomes the selected sector

#### Scenario: Pointer moved far beyond the drawn menu

- **WHEN** the user moves the pointer well past the outer edge of the drawn menu in a given
  direction
- **THEN** the sector for that direction stays selected

#### Scenario: Direction changes during the gesture

- **WHEN** the user moves the pointer toward one sector and then toward another without releasing
  the shortcut
- **THEN** the selection follows the pointer and only the latest sector is selected

### Requirement: Distance from origin chooses between no selection, the centre action, and a direction

The system SHALL interpret the pointer's distance from the gesture origin in three bands: a dead
zone nearest the origin that selects nothing, an intermediate band that selects the centre action,
and an outer band that selects the directional sector matching the pointer's angle.

#### Scenario: Pointer inside the dead zone

- **WHEN** the pointer is within the dead zone of the gesture origin
- **THEN** no sector is selected
- **AND** releasing the shortcut leaves the window unchanged

#### Scenario: Pointer in the centre band

- **WHEN** the pointer is beyond the dead zone but within the centre band
- **THEN** the centre action is selected regardless of direction

#### Scenario: Pointer in the outer band

- **WHEN** the pointer is beyond the centre band
- **THEN** the directional sector matching the pointer's angle is selected

### Requirement: Sectors cover eight directions plus a centre action

The menu SHALL offer the four screen halves, the four corner quarters, and one centre action.

#### Scenario: Each direction is reachable

- **WHEN** the user gestures toward any of the eight compass directions
- **THEN** a distinct sector is selected for each direction
- **AND** no two directions select the same sector

### Requirement: Releasing the modifier commits the selection

The system SHALL apply the selected sector when the shortcut's modifier keys are released, and
SHALL dismiss the menu at the same time.

#### Scenario: Release with a sector selected

- **WHEN** the user releases the modifier keys while a sector is selected
- **THEN** the target window is given that sector's geometry
- **AND** the menu is dismissed

#### Scenario: Release with nothing selected

- **WHEN** the user releases the modifier keys while no sector is selected
- **THEN** the menu is dismissed
- **AND** the target window is left unchanged

#### Scenario: Modifier released before the menu finishes appearing

- **WHEN** the user presses and releases the shortcut faster than the menu can be raised
- **THEN** the menu does not stay on screen
- **AND** the outcome matches the selection state at the moment of release

### Requirement: The gesture can be cancelled

The system SHALL abandon the gesture without changing any window when the user presses Escape.

#### Scenario: Escape during the gesture

- **WHEN** the user presses Escape while the menu is up
- **THEN** the menu is dismissed
- **AND** the target window is left unchanged
- **AND** subsequently releasing the modifier keys does not move the window

### Requirement: The menu always dismisses itself

The menu SHALL NOT remain on screen indefinitely. If the configured shortcut contains no modifier
key that can be released, the menu SHALL dismiss on a timeout.

#### Scenario: Shortcut with no modifier

- **WHEN** the shortcut is configured without any modifier key and the user presses it
- **THEN** the menu dismisses within a bounded time without further input

#### Scenario: Input is grabbed while the menu is up

- **WHEN** the menu is dismissed for any reason
- **THEN** keyboard and pointer input return to the desktop
- **AND** no input grab is left in place

### Requirement: The selected sector is visually distinguished

The menu SHALL show which sector is currently selected, and SHALL show when nothing is selected.

#### Scenario: Selection is indicated

- **WHEN** a sector is selected
- **THEN** that sector is drawn differently from the unselected sectors

#### Scenario: No selection is indicated

- **WHEN** the pointer is in the dead zone
- **THEN** no sector is drawn as selected

### Requirement: The region a gesture would place the window in is shown

While the menu is up, the system SHALL outline the region the target window would occupy if the
gesture were committed, on the gesture's monitor. The outline SHALL follow the selection as it
changes, and SHALL be absent whenever releasing would place nothing.

The outline SHALL be drawn above the target window, so that it remains visible when the region it
marks overlaps where that window already sits.

The outline SHALL be the only thing shown at the region. The target window itself SHALL NOT be drawn
there, and its own geometry SHALL NOT change, until the gesture is committed.

#### Scenario: A sector is selected

- **WHEN** a sector is selected while the menu is up
- **THEN** the region that sector means is outlined
- **AND** the outlined region matches the geometry the window would be given

#### Scenario: The region overlaps the window's current position

- **WHEN** the selected region covers part or all of where the target window already sits
- **THEN** the outline is visible over that window rather than hidden behind it

#### Scenario: Selection changes

- **WHEN** the selection moves from one sector to another
- **THEN** the outline moves to the newly selected region
- **AND** only one region is outlined at a time

#### Scenario: Pointer inside the dead zone

- **WHEN** the pointer is within the dead zone, where releasing would leave the window unchanged
- **THEN** no region is outlined

#### Scenario: Gesture is committed

- **WHEN** the modifier keys are released with a sector selected
- **THEN** the outline is dismissed
- **AND** nothing is left drawn at the region once the window has arrived

#### Scenario: Gesture is cancelled

- **WHEN** the gesture is abandoned with Escape
- **THEN** the outline is dismissed
- **AND** the window is left unchanged

#### Scenario: Gesture made on a monitor other than the target window's

- **WHEN** the gesture is made on a monitor other than the one holding the target window
- **THEN** the outlined region is on the monitor the gesture was made on

### Requirement: The preview can be turned off

The system SHALL offer a preference that suppresses the outline. When it is off, a gesture SHALL
behave in every other respect as it does when it is on.

The preference SHALL govern whether the region is shown, not whether it is animated. When the
desktop is configured not to animate, the outline SHALL still be shown, without motion.

#### Scenario: Default

- **WHEN** the extension is enabled for the first time
- **THEN** the preview is on

#### Scenario: Preference is off

- **WHEN** the preview is turned off and a gesture is made
- **THEN** no region is outlined
- **AND** the selection is still indicated by the menu
- **AND** committing places the window exactly as it would have

#### Scenario: Preference is changed between gestures

- **WHEN** the preference is changed while no gesture is in progress
- **THEN** the next gesture honours the new value without the extension being reloaded

#### Scenario: Desktop animations are off

- **WHEN** the desktop is set not to animate and a sector is selected
- **THEN** the region is outlined at once, with no movement into place

### Requirement: Directions remain reachable near screen edges

Every sector SHALL remain selectable regardless of where on screen the gesture begins, including
when the pointer starts at or near a screen edge and cannot travel further in some direction.

#### Scenario: Gesture started at the right screen edge

- **WHEN** the gesture begins with the pointer against the right edge of the screen
- **AND** the user gestures rightward
- **THEN** the right-hand sector can still be selected
