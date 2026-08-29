// The catalogues, and the properties a translation has to keep.
//
// This is the only tier that sees them at all: the shell draws no text, and the
// preferences run in a process the harness never starts. What rots here is not
// the code but the coverage — an eighth travel style added without re-extracting
// leaves thirteen catalogues silently short of two strings.

import assert from 'node:assert';
import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import test from 'node:test';

import {CURVES, CURVE_KEYS} from '../magunetto@matteopacini.me/lib/curveInfo.js';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const PO = `${ROOT}po`;

const LOCALES = readFileSync(`${PO}/LINGUAS`, 'utf8')
    .split('\n')
    .map(line => line.trim())
    .filter(line => line && !line.startsWith('#'));

// A sentence closes with a full stop in most of these languages and with an
// ideographic one in Japanese and Chinese. Nothing else is a sentence end here.
const SENTENCE_END = /[.。]$/;

// The extraction script owns the xgettext flags, so the test asks it rather than
// repeating them and drifting.
function extractionIsCurrent() {
    return spawnSync(`${PO}/update.sh`, ['--check'], {cwd: ROOT, encoding: 'utf8'});
}

// Minimal reader. These catalogues carry no plural forms and no contexts, so a
// msgid and its msgstr — each able to continue across lines — is all of it.
function readCatalogue(path) {
    const unescape = s => s
        .replace(/\\n/g, '\n')
        .replace(/\\t/g, '\t')
        .replace(/\\"/g, '"')
        .replace(/\\\\/g, '\\');

    const entries = new Map();
    let msgid = null;
    let msgstr = null;
    let field = null;

    const flush = () => {
        if (msgid)
            entries.set(msgid, msgstr ?? '');
        msgid = null;
        msgstr = null;
        field = null;
    };

    for (const raw of readFileSync(path, 'utf8').split('\n')) {
        const line = raw.trim();
        let match;
        if (line === '' || line.startsWith('#'))
            flush();
        else if ((match = /^msgid\s+"(.*)"$/.exec(line)))
            flush(), msgid = unescape(match[1]), field = 'id';
        else if ((match = /^msgstr\s+"(.*)"$/.exec(line)))
            msgstr = unescape(match[1]), field = 'str';
        else if ((match = /^"(.*)"$/.exec(line)) && field === 'id')
            msgid += unescape(match[1]);
        else if ((match = /^"(.*)"$/.exec(line)) && field === 'str')
            msgstr += unescape(match[1]);
    }
    flush();
    return entries;
}

const TEMPLATE = readCatalogue(`${PO}/magunetto.pot`);
const CATALOGUES = new Map(
    LOCALES.map(locale => [locale, readCatalogue(`${PO}/${locale}.po`)]));

// The one schema string that names values the extension stores. Found by what it
// says rather than by position, so reordering the schema cannot silently drop it.
const STORED_VALUES = [...TEMPLATE.keys()].find(id => id.includes('"expo"'));

test('the template accounts for every string the sources can display', () => {
    const result = extractionIsCurrent();
    assert.equal(result.status, 0,
        `${result.stdout}${result.stderr}\nrun po/update.sh`);
});

test('every travel style is in the template', () => {
    for (const key of CURVE_KEYS) {
        assert.ok(TEMPLATE.has(CURVES[key].label),
            `${key}'s name is not extracted`);
        assert.ok(TEMPLATE.has(CURVES[key].description),
            `${key}'s description is not extracted`);
    }
});

test('LINGUAS names thirteen catalogues', () => {
    assert.equal(LOCALES.length, 13);
    assert.ok(!LOCALES.includes('en_GB'), 'en_GB is the source, not a catalogue');
});

for (const locale of LOCALES) {
    const catalogue = CATALOGUES.get(locale);
    const path = `${PO}/${locale}.po`;

    test(`${locale} is complete`, () => {
        const result = spawnSync(
            'msgfmt', ['--check', '--statistics', '--output-file=/dev/null', path],
            {encoding: 'utf8'});
        assert.equal(result.status, 0, result.stderr);
        // Anything untranslated or fuzzy earns a further clause on this line.
        assert.equal(result.stderr.trim(), `${TEMPLATE.size} translated messages.`);
    });

    test(`${locale} translates every string in the template`, () => {
        for (const id of TEMPLATE.keys()) {
            assert.ok(catalogue.get(id),
                `${locale} leaves "${id.slice(0, 40)}" untranslated`);
        }
    });

    test(`${locale} keeps the travel styles distinct`, () => {
        const names = CURVE_KEYS.map(key => catalogue.get(CURVES[key].label));
        assert.equal(new Set(names).size, names.length,
            `${locale} gives two styles the same name: ${names.join(', ')}`);
    });

    test(`${locale} closes every style description as a sentence`, () => {
        for (const key of CURVE_KEYS) {
            const translated = catalogue.get(CURVES[key].description);
            assert.match(translated, SENTENCE_END,
                `${locale}'s ${key} description does not close: ${translated}`);
        }
    });

    test(`${locale} leaves the stored values alone`, () => {
        const translated = catalogue.get(STORED_VALUES);
        for (const key of CURVE_KEYS) {
            assert.ok(translated.includes(key),
                `${locale} translated the stored value ${key}`);
        }
    });
}
