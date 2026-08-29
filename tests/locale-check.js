// Asserts one catalogue resolves from an installed extension tree.
//
//   gjs -m locale-check.js <locale dir> <domain> <locale> <string>
//
// The VM tier runs this once per locale, because it is the only tier that sees
// an installed tree: the unit tier proves the catalogues are complete, and this
// proves they survived the build and that the domain still finds them.
//
// One invocation per locale, not a loop inside one: glibc resolves a domain's
// catalogue on first use and caches it, so a second LANGUAGE in the same process
// is ignored and every locale after the first reports the first one's answer.
//
// LANGUAGE rather than a locale per catalogue, because it needs only one real
// locale to be present. Selecting thirteen through setlocale() would mean
// building them all into the image, and a setlocale() that quietly failed would
// fall back to English and pass this check for the wrong reason.
//
// Imports nothing from GObject introspection, so it needs no typelib path.

import System from 'system';
import {LocaleCategory, bindtextdomain, dgettext, setlocale} from 'gettext';

const [localeDir, domain, locale, source] = ARGV;

// LANGUAGE is consulted only when the message locale is a real one, so a session
// left at C would ignore it and report every catalogue as missing.
if (setlocale(LocaleCategory.MESSAGES, '') === null)
    throw new Error('the environment names no usable locale');

bindtextdomain(domain, localeDir);

const translated = dgettext(domain, source);
if (translated === source) {
    printerr(`${locale}: did not resolve from ${localeDir}`);
    System.exit(1);
}

print(`${locale}: ${translated}`);
