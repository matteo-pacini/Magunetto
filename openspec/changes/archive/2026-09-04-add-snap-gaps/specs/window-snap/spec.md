## MODIFIED Requirements

### Requirement: Sectors map to halves, quarters, and a maximise action

Directional sectors SHALL map to the corresponding half or quarter of the work area, and the centre
action SHALL fill the work area. Each region SHALL be inset by the configured gaps, as the gap
requirement below describes; with both gaps at zero the regions SHALL tile the work area exactly.

#### Scenario: A half is selected

- **WHEN** a left, right, top, or bottom sector is committed
- **THEN** the window occupies that half of the work area, inset by the gaps

#### Scenario: A quarter is selected

- **WHEN** a corner sector is committed
- **THEN** the window occupies that quarter of the work area, inset by the gaps

#### Scenario: The centre action is selected

- **WHEN** the centre action is committed
- **THEN** the window fills the work area, inset by the outer gap

#### Scenario: Adjacent halves do not overlap or leave gaps

- **WHEN** one window is snapped to the left half and another to the right half of the same work
  area
- **THEN** the two windows do not overlap
- **AND** the space between them is exactly the inner gap, so that with the inner gap at zero they
  abut with no unfilled column between them

## ADDED Requirements

### Requirement: Regions are inset by an outer gap and an inner gap

The system SHALL offer two preferences, each a whole number of logical pixels from 0 to 100, and
each 0 by default. The outer gap is the space between a region and the edge of the work area, on
all four sides. The inner gap is the total space between two adjacent regions, so that two windows
snapped to neighbouring regions are exactly that far apart.

A region's side that lies on the work area edge SHALL be inset by the outer gap. A side that a
neighbouring region shares SHALL be inset so that the two regions are the inner gap apart. The
centre action SHALL be inset by the outer gap alone. The gaps SHALL be taken out of the work area
before it is divided, so that regions on either side of a seam are as close to equal as whole
pixels allow. Both values SHALL be read as a gesture begins, so a change applies to the next gesture
without reloading the extension. The gaps SHALL apply on every monitor alike.

#### Scenario: Default

- **WHEN** the extension is enabled for the first time
- **THEN** both gaps are 0
- **AND** every region is exactly the half, quarter, or whole of the work area it was before the
  gaps existed

#### Scenario: A half is inset

- **WHEN** the outer gap and the inner gap are both non-zero and a window is snapped to the left
  half
- **THEN** its left, top, and bottom edges are the outer gap from the work area edge
- **AND** its right edge is the inner gap short of where the right half begins

#### Scenario: A quarter is inset on both axes

- **WHEN** the gaps are non-zero and a window is snapped to a corner quarter
- **THEN** its two outer sides are the outer gap from the work area edge
- **AND** its two inner sides are the inner gap short of the neighbouring quarters on each axis

#### Scenario: Opposite quarters leave one seam on each axis

- **WHEN** one window is snapped to the top-left quarter and another to the bottom-right quarter
- **THEN** the horizontal space between them is exactly the inner gap
- **AND** the vertical space between them is exactly the inner gap

#### Scenario: The centre action honours the outer gap only

- **WHEN** the gaps are non-zero and the centre action is committed
- **THEN** the window is the outer gap from every edge of the work area
- **AND** the inner gap has no effect

#### Scenario: Odd sizes and odd gaps still tile

- **WHEN** the work area has an odd width or height, or the inner gap is odd
- **THEN** the two halves on that axis differ in size by at most one pixel
- **AND** the space between them is still exactly the inner gap

#### Scenario: The outline shows the inset region

- **WHEN** the gaps are non-zero and a sector is selected while the menu is up
- **THEN** the region outlined is the inset region the window would be given

#### Scenario: A gap change applies to the next gesture

- **WHEN** either gap is changed while the extension is enabled
- **THEN** the next gesture uses the new value
- **AND** the extension does not need to be reloaded

#### Scenario: Gaps on a secondary monitor

- **WHEN** the gaps are non-zero and a gesture is made on a secondary monitor
- **THEN** the resulting region is inset from that monitor's work area by the same values

#### Scenario: Repeating a snap with gaps is stable

- **WHEN** the gaps are non-zero and a window is snapped to the same sector twice
- **THEN** its geometry after the second snap matches its geometry after the first
