import test from 'node:test';
import assert from 'node:assert/strict';

import {
    CENTRE,
    CENTRE_BAND_RADIUS,
    DEAD_ZONE_RADIUS,
    DIRECTIONS,
    NONE,
    rectFor,
    sectorFor,
} from '../magunetto@matteopacini.me/lib/geometry.js';

// Unit vectors per direction, in screen coordinates (positive y is downward).
const D = 1 / Math.SQRT2;
const UNIT = {
    'right': [1, 0],
    'bottom-right': [D, D],
    'bottom': [0, 1],
    'bottom-left': [-D, D],
    'left': [-1, 0],
    'top-left': [-D, -D],
    'top': [0, -1],
    'top-right': [D, -D],
};

const OUTER = CENTRE_BAND_RADIUS + 40;

test('dead zone selects nothing', () => {
    assert.equal(sectorFor(0, 0), NONE);
    assert.equal(sectorFor(DEAD_ZONE_RADIUS - 1, 0), NONE);
    assert.equal(sectorFor(0, DEAD_ZONE_RADIUS), NONE);
});

test('centre band selects the centre action regardless of direction', () => {
    const radius = (DEAD_ZONE_RADIUS + CENTRE_BAND_RADIUS) / 2;
    for (const [dx, dy] of Object.values(UNIT))
        assert.equal(sectorFor(dx * radius, dy * radius), CENTRE);

    assert.equal(sectorFor(DEAD_ZONE_RADIUS + 1, 0), CENTRE);
    assert.equal(sectorFor(CENTRE_BAND_RADIUS, 0), CENTRE);
});

test('outer band selects the direction the pointer moved in', () => {
    for (const [name, [dx, dy]] of Object.entries(UNIT))
        assert.equal(sectorFor(dx * OUTER, dy * OUTER), name);
});

test('every direction is reachable and distinct', () => {
    const selected = Object.values(UNIT).map(([dx, dy]) => sectorFor(dx * OUTER, dy * OUTER));
    assert.equal(new Set(selected).size, DIRECTIONS.length);
});

test('direction survives moving far past the menu', () => {
    for (const [name, [dx, dy]] of Object.entries(UNIT))
        assert.equal(sectorFor(dx * 10000, dy * 10000), name);
});

test('sector boundaries fall midway between axes', () => {
    // Just inside the boundary either side of due right stays "right".
    const almost = Math.PI / 8 - 0.01;
    for (const sign of [1, -1]) {
        const dx = Math.cos(sign * almost) * OUTER;
        const dy = Math.sin(sign * almost) * OUTER;
        assert.equal(sectorFor(dx, dy), 'right');
    }
});

const AREAS = [
    {x: 0, y: 0, width: 1280, height: 800},
    {x: 0, y: 32, width: 1280, height: 768},
    {x: 1920, y: 27, width: 2560, height: 1413}, // secondary monitor, odd size
    {x: 0, y: 0, width: 1281, height: 801}, // odd both ways
];

test('centre action fills the work area', () => {
    for (const area of AREAS)
        assert.deepEqual(rectFor(CENTRE, area), area);
});

test('nothing selected yields no rectangle', () => {
    assert.equal(rectFor(NONE, AREAS[0]), null);
});

test('halves abut with no gap and no overlap', () => {
    for (const area of AREAS) {
        const left = rectFor('left', area);
        const right = rectFor('right', area);
        assert.equal(left.x, area.x);
        assert.equal(left.x + left.width, right.x, 'no gap or overlap between halves');
        assert.equal(right.x + right.width, area.x + area.width, 'halves reach the far edge');
        assert.equal(left.height, area.height);
        assert.equal(right.height, area.height);

        const top = rectFor('top', area);
        const bottom = rectFor('bottom', area);
        assert.equal(top.y, area.y);
        assert.equal(top.y + top.height, bottom.y);
        assert.equal(bottom.y + bottom.height, area.y + area.height);
        assert.equal(top.width, area.width);
        assert.equal(bottom.width, area.width);
    }
});

test('quarters tile the work area exactly', () => {
    for (const area of AREAS) {
        const quarters = ['top-left', 'top-right', 'bottom-left', 'bottom-right']
            .map(sector => rectFor(sector, area));

        const covered = quarters.reduce((sum, r) => sum + r.width * r.height, 0);
        assert.equal(covered, area.width * area.height, 'quarters cover the area with no overlap');

        for (const r of quarters) {
            assert.ok(r.x >= area.x && r.y >= area.y, 'quarter starts inside the area');
            assert.ok(r.x + r.width <= area.x + area.width, 'quarter stays inside horizontally');
            assert.ok(r.y + r.height <= area.y + area.height, 'quarter stays inside vertically');
        }
    }
});

test('every rectangle stays within the work area', () => {
    for (const area of AREAS) {
        for (const sector of [CENTRE, ...DIRECTIONS]) {
            const r = rectFor(sector, area);
            assert.ok(r.width > 0 && r.height > 0, `${sector} has positive size`);
            assert.ok(r.x >= area.x, `${sector} starts at or after the left edge`);
            assert.ok(r.x + r.width <= area.x + area.width, `${sector} ends within the right edge`);
            assert.ok(r.y >= area.y, `${sector} starts at or below the top edge`);
            assert.ok(r.y + r.height <= area.y + area.height, `${sector} ends within the bottom edge`);
        }
    }
});
