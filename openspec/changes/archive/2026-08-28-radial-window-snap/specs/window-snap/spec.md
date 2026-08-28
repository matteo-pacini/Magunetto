## Purpose

Turns a chosen screen region into an actual window placement: picks the window to act on, works out
the rectangle that region means on that window's monitor, and applies it reliably to windows that
are maximised, tiled, or fussy about their own size.

## ADDED Requirements

### Requirement: The target window is the focused window at invocation time

The system SHALL act on the window that holds keyboard focus at the moment the gesture begins, and
SHALL continue to act on that same window for the whole gesture even if focus changes.

#### Scenario: Focused window is snapped

- **WHEN** a gesture is committed
- **THEN** the window that was focused when the gesture began is the window that moves

#### Scenario: Focus changes mid-gesture

- **WHEN** keyboard focus moves to another window after the gesture began
- **THEN** the originally focused window is still the one that moves

#### Scenario: Target window disappears mid-gesture

- **WHEN** the target window closes before the gesture is committed
- **THEN** no window is moved
- **AND** no error is surfaced to the user

### Requirement: Windows that cannot be placed are refused

The system SHALL only act on windows that permit being moved and resized. Windows that do not —
including windows that refuse resizing, and desktop or panel surfaces that are not ordinary
application windows — SHALL be left untouched.

#### Scenario: Window refuses to be resized

- **WHEN** the target window does not permit resizing
- **THEN** the window is left unchanged

#### Scenario: Desktop or panel surface is focused

- **WHEN** the focused surface is not an ordinary application window
- **THEN** no gesture is started and nothing is moved

### Requirement: Geometry is computed within the monitor work area

Snapped geometry SHALL be computed from the work area of the monitor holding the target window, so
that snapped windows do not overlap panels, docks, or other reserved space.

#### Scenario: Panel is present

- **WHEN** a window is snapped on a monitor that has a panel reserving space
- **THEN** the resulting window does not overlap the reserved space

#### Scenario: Window on a secondary monitor

- **WHEN** the target window is on a secondary monitor
- **THEN** the resulting geometry falls within that monitor's work area
- **AND** the window does not move to another monitor

#### Scenario: Monitors have different sizes

- **WHEN** the same sector is used on monitors of different sizes
- **THEN** the resulting geometry is proportional to each monitor's own work area

### Requirement: Sectors map to halves, quarters, and a maximise action

Directional sectors SHALL map to the corresponding half or quarter of the work area, and the centre
action SHALL fill the work area.

#### Scenario: A half is selected

- **WHEN** a left, right, top, or bottom sector is committed
- **THEN** the window occupies that half of the work area

#### Scenario: A quarter is selected

- **WHEN** a corner sector is committed
- **THEN** the window occupies that quarter of the work area

#### Scenario: The centre action is selected

- **WHEN** the centre action is committed
- **THEN** the window fills the work area

#### Scenario: Adjacent halves do not overlap or leave gaps

- **WHEN** one window is snapped to the left half and another to the right half of the same work
  area
- **THEN** the two windows abut without overlapping and without leaving an unfilled column between
  them

### Requirement: Maximised and fullscreen state is cleared before placing

The system SHALL clear any maximised or fullscreen state on the target window before applying new
geometry, so that the requested placement takes effect rather than being ignored.

#### Scenario: Maximised window is snapped

- **WHEN** a maximised window is snapped to a half
- **THEN** the window is no longer maximised
- **AND** it occupies that half

#### Scenario: Fullscreen window is snapped

- **WHEN** a fullscreen window is snapped
- **THEN** the window leaves fullscreen
- **AND** it takes the requested geometry

### Requirement: Placement succeeds for windows that constrain their own size

The system SHALL place windows that enforce size increments, minimum sizes, or fixed aspect ratios
as closely as those constraints allow, and SHALL position such windows at the correct origin rather
than leaving them where they were.

#### Scenario: Window with size increments

- **WHEN** a window that resizes only in fixed increments is snapped to a half
- **THEN** the window moves to that half's origin
- **AND** its size is as close to the requested size as its increments allow

#### Scenario: Window with a minimum size larger than the target

- **WHEN** the requested geometry is smaller than the window's minimum size
- **THEN** the window moves to the requested origin
- **AND** it remains at its minimum size

### Requirement: Repeating a snap is stable

Applying the same sector to the same window twice in a row SHALL leave the window in the same place
as after the first application.

#### Scenario: Same sector applied twice

- **WHEN** a window is snapped to a sector and then snapped to the same sector again
- **THEN** its geometry after the second snap matches its geometry after the first
