// Gesture mathematics. This module must not import anything: it is unit-tested
// outside a running shell, and the overlay reads the same constants so that what
// is drawn matches what is selected.

export const NONE = 'none';
export const CENTRE = 'centre';

// Directions in screen order, starting at "pointing right" and going clockwise.
// Screen coordinates put positive y downward, so clockwise on screen is the
// direction of increasing angle from Math.atan2.
export const DIRECTIONS = [
    'right',
    'bottom-right',
    'bottom',
    'bottom-left',
    'left',
    'top-left',
    'top',
    'top-right',
];

export const SECTORS = [CENTRE, ...DIRECTIONS];

// Distance bands, in logical pixels, measured from where the gesture began.
export const DEAD_ZONE_RADIUS = 12;
export const CENTRE_BAND_RADIUS = 56;

const SECTOR_SPAN = (2 * Math.PI) / DIRECTIONS.length;

/**
 * Maps accumulated pointer movement to a selection.
 *
 * @param {number} dx horizontal movement since the gesture began
 * @param {number} dy vertical movement since the gesture began, positive downward
 * @returns {string} NONE, CENTRE, or one of DIRECTIONS
 */
export function sectorFor(dx, dy) {
    const distance = Math.hypot(dx, dy);

    if (distance <= DEAD_ZONE_RADIUS)
        return NONE;
    if (distance <= CENTRE_BAND_RADIUS)
        return CENTRE;

    const angle = Math.atan2(dy, dx);
    const index = Math.round(angle / SECTOR_SPAN);

    // Math.round pushes the boundary half a span so each direction is centred on
    // its own axis rather than starting at it.
    return DIRECTIONS[((index % DIRECTIONS.length) + DIRECTIONS.length) % DIRECTIONS.length];
}

export const NO_GAPS = {outer: 0, inner: 0};

// The gaps come out of the span before it is divided, so every edge lands on a
// whole pixel: insetting each half by inner / 2 afterwards would put the seam on
// a half pixel whenever inner is odd. Splitting with floor for the near half and
// taking the remainder for the far half keeps the two within a pixel of each
// other, and abutting exactly when the gap is zero.
function split(start, span, {outer, inner}) {
    const usable = span - 2 * outer - inner;
    const near = Math.floor(usable / 2);
    return {
        near: {start: start + outer, size: near},
        far: {start: start + outer + near + inner, size: usable - near},
    };
}

function whole(start, span, {outer}) {
    return {start: start + outer, size: span - 2 * outer};
}

/**
 * Maps a selection to a rectangle inside a work area.
 *
 * @param {string} sector NONE, CENTRE, or one of DIRECTIONS
 * @param {{x: number, y: number, width: number, height: number}} area work area
 * @param {{outer: number, inner: number}} [gaps] outer is the space between a
 *   region and the work area edge, on every side; inner is the total space
 *   between two adjacent regions. The centre action honours outer alone.
 * @returns {?{x: number, y: number, width: number, height: number}} null when
 *   the sector selects nothing
 */
export function rectFor(sector, area, gaps = NO_GAPS) {
    if (sector === NONE)
        return null;

    const {near: left, far: right} = split(area.x, area.width, gaps);
    const {near: top, far: bottom} = split(area.y, area.height, gaps);
    const wide = whole(area.x, area.width, gaps);
    const tall = whole(area.y, area.height, gaps);

    const rect = (h, v) => ({x: h.start, y: v.start, width: h.size, height: v.size});

    switch (sector) {
    case CENTRE:
        return rect(wide, tall);
    case 'left':
        return rect(left, tall);
    case 'right':
        return rect(right, tall);
    case 'top':
        return rect(wide, top);
    case 'bottom':
        return rect(wide, bottom);
    case 'top-left':
        return rect(left, top);
    case 'top-right':
        return rect(right, top);
    case 'bottom-left':
        return rect(left, bottom);
    case 'bottom-right':
        return rect(right, bottom);
    default:
        throw new Error(`unknown sector: ${sector}`);
    }
}
