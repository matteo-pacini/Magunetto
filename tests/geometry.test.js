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

// Gap pairs: none, even, an odd inner that would put a seam on a half pixel if
// the halves were inset separately, and both at the schema's upper bound.
const GAPS = [
    {outer: 0, inner: 0},
    {outer: 8, inner: 12},
    {outer: 5, inner: 7},
    {outer: 100, inner: 100},
];

const QUARTERS = ['top-left', 'top-right', 'bottom-left', 'bottom-right'];

test('no gaps reproduces the two-argument rectangles', () => {
    for (const area of AREAS) {
        for (const sector of [CENTRE, ...DIRECTIONS])
            assert.deepEqual(rectFor(sector, area, {outer: 0, inner: 0}), rectFor(sector, area));
    }
});

test('halves are the outer gap from the edges and the inner gap apart', () => {
    for (const area of AREAS) {
        for (const gaps of GAPS) {
            const left = rectFor('left', area, gaps);
            const right = rectFor('right', area, gaps);
            assert.equal(left.x, area.x + gaps.outer, 'left half starts an outer gap in');
            assert.equal(right.x - (left.x + left.width), gaps.inner, 'halves are an inner gap apart');
            assert.equal(right.x + right.width, area.x + area.width - gaps.outer,
                'right half ends an outer gap short');
            assert.ok(Math.abs(left.width - right.width) <= 1, 'halves differ by at most a pixel');
            for (const half of [left, right]) {
                assert.equal(half.y, area.y + gaps.outer, 'half is an outer gap from the top');
                assert.equal(half.height, area.height - 2 * gaps.outer,
                    'half is an outer gap from the bottom');
            }

            const top = rectFor('top', area, gaps);
            const bottom = rectFor('bottom', area, gaps);
            assert.equal(top.y, area.y + gaps.outer);
            assert.equal(bottom.y - (top.y + top.height), gaps.inner);
            assert.equal(bottom.y + bottom.height, area.y + area.height - gaps.outer);
            assert.ok(Math.abs(top.height - bottom.height) <= 1);
            for (const half of [top, bottom]) {
                assert.equal(half.x, area.x + gaps.outer);
                assert.equal(half.width, area.width - 2 * gaps.outer);
            }
        }
    }
});

test('quarters compose the two axes and leave one seam per axis', () => {
    for (const area of AREAS) {
        for (const gaps of GAPS) {
            const [tl, tr, bl, br] = QUARTERS.map(sector => rectFor(sector, area, gaps));

            assert.equal(tl.x, area.x + gaps.outer);
            assert.equal(tl.y, area.y + gaps.outer);
            assert.equal(br.x + br.width, area.x + area.width - gaps.outer);
            assert.equal(br.y + br.height, area.y + area.height - gaps.outer);

            assert.equal(tr.x - (tl.x + tl.width), gaps.inner, 'top quarters an inner gap apart');
            assert.equal(bl.y - (tl.y + tl.height), gaps.inner, 'left quarters an inner gap apart');
            assert.equal(br.x - (bl.x + bl.width), gaps.inner, 'bottom quarters an inner gap apart');
            assert.equal(br.y - (tr.y + tr.height), gaps.inner, 'right quarters an inner gap apart');

            // Opposite corners see the same single seam on each axis.
            assert.equal(br.x - (tl.x + tl.width), gaps.inner);
            assert.equal(br.y - (tl.y + tl.height), gaps.inner);

            // A quarter is its half's column crossed with its half's row.
            assert.deepEqual([tl.x, tl.width], [rectFor('left', area, gaps).x, rectFor('left', area, gaps).width]);
            assert.deepEqual([tl.y, tl.height], [rectFor('top', area, gaps).y, rectFor('top', area, gaps).height]);
        }
    }
});

test('centre action is inset by the outer gap alone', () => {
    for (const area of AREAS) {
        for (const gaps of GAPS) {
            const expected = {
                x: area.x + gaps.outer,
                y: area.y + gaps.outer,
                width: area.width - 2 * gaps.outer,
                height: area.height - 2 * gaps.outer,
            };
            assert.deepEqual(rectFor(CENTRE, area, gaps), expected);
            assert.deepEqual(rectFor(CENTRE, area, {...gaps, inner: 0}), expected,
                'inner gap has no effect on the centre action');
        }
    }
});

test('every gapped rectangle has positive size and stays within the work area', () => {
    for (const area of AREAS) {
        for (const gaps of GAPS) {
            for (const sector of [CENTRE, ...DIRECTIONS]) {
                const r = rectFor(sector, area, gaps);
                assert.ok(r.width > 0 && r.height > 0, `${sector} has positive size`);
                assert.ok(r.x >= area.x + gaps.outer);
                assert.ok(r.x + r.width <= area.x + area.width - gaps.outer);
                assert.ok(r.y >= area.y + gaps.outer);
                assert.ok(r.y + r.height <= area.y + area.height - gaps.outer);
            }
        }
    }
});
