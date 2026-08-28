## Purpose

Lets a user pick a screen region by gesturing in a direction rather than aiming at a target: a
shortcut raises a radial menu, pointer movement away from the gesture origin selects a sector, and
releasing the shortcut commits that choice.

## ADDED Requirements

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

### Requirement: Menu appears on the monitor of the target window

The menu SHALL be drawn on the monitor containing the window that will be acted upon, so that the
gesture and its effect are on the same screen.

#### Scenario: Focused window on a secondary monitor

- **WHEN** the shortcut is pressed while the focused window is on a secondary monitor
- **THEN** the menu is drawn on that secondary monitor

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

### Requirement: Directions remain reachable near screen edges

Every sector SHALL remain selectable regardless of where on screen the gesture begins, including
when the pointer starts at or near a screen edge and cannot travel further in some direction.

#### Scenario: Gesture started at the right screen edge

- **WHEN** the gesture begins with the pointer against the right edge of the screen
- **AND** the user gestures rightward
- **THEN** the right-hand sector can still be selected
