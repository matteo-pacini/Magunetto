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

// Splitting with floor for the near half and taking the remainder for the far
// half keeps adjacent halves abutting exactly on odd-sized work areas.
function splitHorizontal(area) {
    const leftWidth = Math.floor(area.width / 2);
    return {leftWidth, rightWidth: area.width - leftWidth};
}

function splitVertical(area) {
    const topHeight = Math.floor(area.height / 2);
    return {topHeight, bottomHeight: area.height - topHeight};
}

/**
 * Maps a selection to a rectangle inside a work area.
 *
 * @param {string} sector NONE, CENTRE, or one of DIRECTIONS
 * @param {{x: number, y: number, width: number, height: number}} area work area
 * @returns {?{x: number, y: number, width: number, height: number}} null when
 *   the sector selects nothing
 */
export function rectFor(sector, area) {
    if (sector === NONE)
        return null;
    if (sector === CENTRE)
        return {x: area.x, y: area.y, width: area.width, height: area.height};

    const {leftWidth, rightWidth} = splitHorizontal(area);
    const {topHeight, bottomHeight} = splitVertical(area);

    const midX = area.x + leftWidth;
    const midY = area.y + topHeight;

    switch (sector) {
    case 'left':
        return {x: area.x, y: area.y, width: leftWidth, height: area.height};
    case 'right':
        return {x: midX, y: area.y, width: rightWidth, height: area.height};
    case 'top':
        return {x: area.x, y: area.y, width: area.width, height: topHeight};
    case 'bottom':
        return {x: area.x, y: midY, width: area.width, height: bottomHeight};
    case 'top-left':
        return {x: area.x, y: area.y, width: leftWidth, height: topHeight};
    case 'top-right':
        return {x: midX, y: area.y, width: rightWidth, height: topHeight};
    case 'bottom-left':
        return {x: area.x, y: midY, width: leftWidth, height: bottomHeight};
    case 'bottom-right':
        return {x: midX, y: midY, width: rightWidth, height: bottomHeight};
    default:
        throw new Error(`unknown sector: ${sector}`);
    }
}
