import assert from 'node:assert/strict';
import {test} from 'node:test';

import {
    CURVES,
    CURVE_KEYS,
    DEFAULT_CURVE,
    infoFor,
} from '../magunetto@matteopacini.me/lib/curveInfo.js';

test('seven styles are offered', () => {
    assert.equal(CURVE_KEYS.length, 7);
});

test('the default is one of them', () => {
    assert.ok(CURVE_KEYS.includes(DEFAULT_CURVE));
    assert.equal(DEFAULT_CURVE, 'quint');
});

test('every style has a label and a description', () => {
    for (const key of CURVE_KEYS) {
        const {label, description} = CURVES[key];
        assert.ok(label, `${key} has no label`);
        assert.ok(description, `${key} has no description`);
        assert.ok(description.endsWith('.'), `${key} description is not a sentence`);
    }
});

test('labels are distinct', () => {
    const labels = CURVE_KEYS.map(key => CURVES[key].label);
    assert.equal(new Set(labels).size, labels.length);
});

test('every style resolves', () => {
    for (const key of CURVE_KEYS)
        assert.equal(infoFor(key), CURVES[key]);
});

test('an unknown style falls back to the default', () => {
    assert.equal(infoFor('no-such-curve'), CURVES[DEFAULT_CURVE]);
    assert.equal(infoFor(''), CURVES[DEFAULT_CURVE]);
});

test('every style eases either by name or by bezier, not neither', () => {
    for (const key of CURVE_KEYS) {
        const {translate, scale, bezier} = CURVES[key];
        if (bezier)
            assert.equal(bezier.length, 4, `${key} bezier needs four control values`);
        else
            assert.ok(translate && scale, `${key} names no easing`);
    }
});

// Overshoot on scale draws the window larger than the region it is snapping
// into. Only the style whose description says so may do it.
test('only Overshoot overshoots its size', () => {
    for (const key of CURVE_KEYS) {
        if (CURVES[key].scale !== 'EASE_OUT_BACK')
            continue;
        assert.equal(key, 'back');
        assert.match(CURVES[key].description, /exceeding its region/);
    }
});
