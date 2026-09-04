## Purpose

Turns a chosen screen region into an actual window placement: picks the window to act on, works out
the rectangle that region means on that window's monitor, and applies it reliably to windows that
are maximised, tiled, or fussy about their own size.

## Requirements

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
