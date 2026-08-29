## MODIFIED Requirements

### Requirement: Geometry is computed within the monitor work area

Snapped geometry SHALL be computed from the work area of the monitor the gesture was made on, so
that snapped windows do not overlap panels, docks, or other reserved space. Where that monitor is
not the one holding the target window, the window SHALL be moved to it.

#### Scenario: Panel is present

- **WHEN** a window is snapped on a monitor that has a panel reserving space
- **THEN** the resulting window does not overlap the reserved space

#### Scenario: Window on a secondary monitor

- **WHEN** the target window is on a secondary monitor and the gesture is made on that same monitor
- **THEN** the resulting geometry falls within that monitor's work area
- **AND** the window does not move to another monitor

#### Scenario: Gesture made on a monitor other than the target window's

- **WHEN** the target window is on one monitor and the gesture is made on another
- **THEN** the window moves to the monitor the gesture was made on
- **AND** the resulting geometry falls within that monitor's work area

#### Scenario: Maximised window is sent to another monitor

- **WHEN** a maximised window is snapped by a gesture made on a different monitor
- **THEN** the window is no longer maximised
- **AND** it occupies the selected region of the gesture's monitor

#### Scenario: Monitors have different sizes

- **WHEN** the same sector is used on monitors of different sizes
- **THEN** the resulting geometry is proportional to each monitor's own work area
