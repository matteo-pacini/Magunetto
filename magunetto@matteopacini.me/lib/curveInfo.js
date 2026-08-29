// The travel styles on offer: what they are called, how they are described, and
// which easing each uses.
//
// Imports nothing, like geometry.js, for two reasons: the preferences run in
// their own process and must not pull the compositor's toolkit into it, and the
// table can then be unit-tested without a shell. Easing modes are named rather
// than resolved here; curves.js turns the names into Clutter values.
//
// Every style decelerates. The gesture is already committed by the time the
// window starts moving, so it is arriving rather than departing: a style that
// eased in would read as lag on a decision the user has already made.
//
// `translate` and `scale` are separate because overshoot means different things
// for each. Applied to scale it draws the window larger than the region it is
// snapping into, lapping over whatever is beside it; applied to the slide alone
// it reads as momentum.

export const DEFAULT_CURVE = 'quint';

// Declaration order is presentation order: the sharpness ladder first, then the
// two with a character of their own.
export const CURVES = {
    expo: {
        label: 'Instant',
        description: 'Almost immediate, then a long drift into place.',
        translate: 'EASE_OUT_EXPO',
        scale: 'EASE_OUT_EXPO',
    },
    quint: {
        label: 'Snappy',
        description: 'Most of the move happens at once, then it settles.',
        translate: 'EASE_OUT_QUINT',
        scale: 'EASE_OUT_QUINT',
    },
    md: {
        label: 'Settle',
        description: 'Quick to move, unhurried to stop.',
        bezier: [0.05, 0.7, 0.1, 1.0],
    },
    cubic: {
        label: 'Soft',
        description: "Sharper than GNOME's own, still gentle at the end.",
        translate: 'EASE_OUT_CUBIC',
        scale: 'EASE_OUT_CUBIC',
    },
    quad: {
        label: 'Standard',
        description: 'The curve GNOME uses for its own window animations.',
        translate: 'EASE_OUT_QUAD',
        scale: 'EASE_OUT_QUAD',
    },
    spring: {
        label: 'Spring',
        description: 'Overshoots as it slides, but never grows past its region.',
        translate: 'EASE_OUT_BACK',
        scale: 'EASE_OUT_QUINT',
    },
    back: {
        label: 'Overshoot',
        description: 'Slides past the target and comes back, briefly exceeding its region.',
        translate: 'EASE_OUT_BACK',
        scale: 'EASE_OUT_BACK',
    },
};

export const CURVE_KEYS = Object.keys(CURVES);

export function infoFor(name) {
    return CURVES[name] ?? CURVES[DEFAULT_CURVE];
}
