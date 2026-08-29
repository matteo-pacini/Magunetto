// Turning a travel style into something Clutter can ease with.
//
// The styles themselves live in curveInfo.js, which imports nothing so that the
// preferences process and the unit tests can read them without the compositor's
// toolkit.

import Clutter from 'gi://Clutter';
import Graphene from 'gi://Graphene';

import {infoFor} from './curveInfo.js';

export function curveFor(name) {
    const info = infoFor(name);

    return {
        translate: Clutter.AnimationMode[info.translate],
        scale: Clutter.AnimationMode[info.scale],
        bezier: info.bezier,
    };
}

// Clutter exposes Bézier control points on the transition rather than through
// ease(), so they can only be set once ease() has created them.
export function easeWith(actor, props, mode, bezier, duration, onStopped) {
    actor.ease({
        ...props,
        duration,
        mode: bezier ? Clutter.AnimationMode.CUBIC_BEZIER : mode,
        onStopped,
    });

    if (!bezier)
        return;

    const [x1, y1, x2, y2] = bezier;
    for (const prop of Object.keys(props)) {
        actor.get_transition(prop.replaceAll('_', '-'))?.set_cubic_bezier_progress(
            new Graphene.Point({x: x1, y: y1}),
            new Graphene.Point({x: x2, y: y2}));
    }
}
