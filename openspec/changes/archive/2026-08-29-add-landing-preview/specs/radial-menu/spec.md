## ADDED Requirements

### Requirement: The region a gesture would place the window in is shown

While the menu is up, the system SHALL outline the region the target window would occupy if the
gesture were committed, on the gesture's monitor. The outline SHALL follow the selection as it
changes, and SHALL be absent whenever releasing would place nothing.

The outline SHALL be the only thing shown at the region. The target window itself SHALL NOT be drawn
there, and its own geometry SHALL NOT change, until the gesture is committed.

#### Scenario: A sector is selected

- **WHEN** a sector is selected while the menu is up
- **THEN** the region that sector means is outlined
- **AND** the outlined region matches the geometry the window would be given

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
