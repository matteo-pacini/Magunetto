## ADDED Requirements

### Requirement: A snapped window travels to its region

When a gesture is committed the window SHALL be seen to move and resize from the rectangle it
occupied into the rectangle it is snapped to, rather than appearing there. The travel SHALL look the
same for every sector and SHALL NOT depend on what state the window was in beforehand.

The rectangle a window ends up in SHALL NOT be affected by this. Every geometry requirement of this
capability holds unchanged.

#### Scenario: Window moves between regions of different size

- **WHEN** a window is snapped to a region whose size differs from its current size
- **THEN** it is seen to travel from where it was to that region
- **AND** it comes to rest exactly on that region

#### Scenario: Window moves between regions of the same size

- **WHEN** a window is snapped from one region to another of identical size, such as one half to the
  opposite half
- **THEN** it is seen to travel between them
- **AND** it comes to rest exactly on the second region

#### Scenario: Maximised window is snapped

- **WHEN** a maximised window is snapped to a region
- **THEN** it travels to that region as one continuous movement
- **AND** the movement is the same one an ordinary window would make

#### Scenario: Fullscreen window is snapped

- **WHEN** a fullscreen window is snapped to a region
- **THEN** it travels to that region as one continuous movement

#### Scenario: Window that constrains its own size is snapped

- **WHEN** a window that cannot take the requested size is snapped
- **THEN** it travels to the geometry it is actually able to take
- **AND** the travel still completes

### Requirement: The destination is not revealed before the travel

The window SHALL NOT be drawn at its destination before the travel starts. There SHALL be no point
at which the window appears in its new region, returns to its old one, and then travels.

#### Scenario: Committing a gesture

- **WHEN** a gesture is committed
- **THEN** the first thing seen at the destination is the end of the travel, not the start of it

### Requirement: The travel always completes

Every snap SHALL leave the window displayed at its true geometry once the travel ends. A window
SHALL NOT be left displaced, scaled, or frozen, regardless of how the travel ends.

#### Scenario: Another snap interrupts the travel

- **WHEN** a second gesture is committed while a window is still travelling
- **THEN** the window travels to the second region
- **AND** it comes to rest displayed at that region's geometry

#### Scenario: The window closes while travelling

- **WHEN** the window is closed before its travel ends
- **THEN** no error is surfaced
- **AND** nothing is left drawn where the window was

#### Scenario: Snapping to the region already occupied

- **WHEN** a window is snapped to the region it already occupies
- **THEN** it stays where it is
- **AND** a subsequent snap to a different region still travels and lands correctly

#### Scenario: The window never takes the offered geometry

- **WHEN** a window does not respond to being given new geometry
- **THEN** it is still displayed normally afterwards
- **AND** it continues to update

### Requirement: The travel can be turned off

The system SHALL offer a preference that disables the travel. When disabled, a committed gesture
SHALL place the window in its region immediately.

#### Scenario: Preference is off

- **WHEN** the travel is disabled and a gesture is committed
- **THEN** the window occupies its region with no intermediate movement

#### Scenario: Preference is on

- **WHEN** the travel is enabled and a gesture is committed
- **THEN** the window travels to its region

#### Scenario: Default

- **WHEN** the extension is enabled for the first time
- **THEN** the travel is on

### Requirement: The character of the travel is selectable

The system SHALL offer a choice of seven named travel styles, and SHALL apply the chosen one to
subsequent snaps. Each SHALL be presented with a plain-language description of how it looks, so the
choice can be made without trying each one.

The styles SHALL be: Instant, Snappy, Settle, Soft, Standard, Spring, and Overshoot. Snappy SHALL be
the default.

#### Scenario: Default style

- **WHEN** the extension is enabled for the first time
- **THEN** the travel style is Snappy

#### Scenario: Choosing a style

- **WHEN** a different style is chosen
- **THEN** subsequent snaps travel in that style
- **AND** the choice persists across sessions

#### Scenario: Styles are described

- **WHEN** the styles are offered for selection
- **THEN** each one is accompanied by a description of how the travel will look

#### Scenario: A style that exceeds the region

- **WHEN** a style whose travel carries the window past its region is offered
- **THEN** its description says so

### Requirement: Desktop animation preferences are honoured

When the desktop is configured not to animate, snapping SHALL be immediate regardless of this
capability's own preferences.

#### Scenario: Desktop animations are off

- **WHEN** the desktop is set not to animate and a gesture is committed
- **THEN** the window occupies its region with no intermediate movement
- **AND** it comes to rest exactly on that region
