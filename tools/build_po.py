#!/usr/bin/env python3
## Builds the gettext files i18n/en.po and i18n/ca.po from the key tables in docs/.
## Usage: python3 -I tools/build_po.py
## Each table row is `KEY | Catalan original | English proposal`. msgid is the KEY; msgstr is the English (en.po) or the Catalan (ca.po).
## Checks: placeholders (%s, %d, ...) must match in order between the two languages; keys in more than one table are reported.
## Exit code 1 on errors (bad rows, English fixes that no longer match, empty texts); placeholder mismatches and duplicates are only printed.
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
## Read in this order; when a key is in several tables the LATER one wins (ui beats sim, extra beats both).
SOURCES = [
    "docs/i18n_keys_sim.md",
    "docs/i18n_keys_ui.md",
    "docs/i18n_keys_extra.md",
    "docs/i18n_keys_story_sim.md",
    "docs/i18n_keys_story_ui.md",
    "docs/i18n_keys_story_levels.md",
    "docs/i18n_keys_story_view.md",
    "docs/i18n_keys_platform_sim.md",
    "docs/i18n_keys_platform_view.md",
    "docs/i18n_keys_touch.md",
    "docs/i18n_keys_boss_sim.md",
    "docs/i18n_keys_boss_view.md",
    "docs/i18n_keys_cuca.md",
    "docs/i18n_keys_nest_sim.md",
    "docs/i18n_keys_nest_view.md",
    "docs/i18n_keys_plat2.md",
    "docs/i18n_keys_plat2_view.md",
    "docs/i18n_keys_proc.md",
    "docs/i18n_keys_proc_view.md",
    "docs/i18n_keys_stomp.md",
    "docs/i18n_keys_buttons.md",
    "docs/i18n_keys_silk.md",
    "docs/i18n_keys_uiscale.md",
    "docs/i18n_keys_touchphases.md",
    "docs/i18n_keys_levels2.md",
    "docs/i18n_keys_stages.md",
    "docs/i18n_keys_silk2.md",
]
KEY_RE = re.compile(r"[A-Z][A-Z0-9_]+")
PLACEHOLDER_RE = re.compile(r"%[-+ #0]*\d*(?:\.\d+)?[sdifxc]")

## English corrections on top of the proposals (the sim and ui tables belong to other agents and are not edited here).
## Each entry is (text the table currently has, corrected text); a stale entry is reported as an error.
EN_FIXES = {
    "FT_ESCUDELLA_EXPLODE": ("EXPLOSIVE STEW! RAIN OF PASTA SHELLS!", "EXPLOSIVE ESCUDELLA! RAIN OF PASTA SHELLS!"),
    "FT_CARQUINYOLIS": ("TOOTH-BREAKING BISCUITS!", "TOOTH-BREAKING CARQUINYOLIS!"),
    "TAUNT_TURN_5": ("Tooth-breaking biscuit!", "Tooth-breaking carquinyoli!"),
    "FT_TIO": ("POOP LOG, POOP NOUGAT!", "CAGA TIÓ, CAGA TORRÓ!"),
    "FT_DYNAMITE_BOOM": ("POOP LOG!", "CAGA TIÓ!"),
    "FT_CASTELL": ("CATERPILLAR TOWER! +30% TOP-CLIMBER STRENGTH!", "CASTELL DE CUCS! +30% TOP-CLIMBER STRENGTH!"),
    "BUBBLE_CASTELL": ("Caterpillar tower! Aleta!", "Castell de Cucs! Aleta!"),
    "HUD_SWITCH_WORM": ("Worm ⇄", "Caterpillar ⇄"),
    "SPLASH_KICKER": ("Thaumetopoea Pityocampa · Tactical War in the Pine Forests of Catalonia",
                      "Thaumetopoea pityocampa · Tactical War in the Pine Forests of Catalonia"),
}

HEADER = (
    'msgid ""\n'
    'msgstr ""\n'
    '"Project-Id-Version: CUCS\\n"\n'
    '"Language: {lang}\\n"\n'
    '"MIME-Version: 1.0\\n"\n'
    '"Content-Type: text/plain; charset=UTF-8\\n"\n'
    '"Content-Transfer-Encoding: 8bit\\n"\n'
    '"Plural-Forms: nplurals=2; plural=(n != 1);\\n"\n'
    '\n'
)


def rel(path):
    return os.path.relpath(path, ROOT)


def parse_table(path):
    ## Returns [(key, catalan, english, line_no)] for the rows of one table; other lines are ignored.
    rows = []
    with open(path, encoding="utf-8") as fh:
        for n, raw in enumerate(fh, 1):
            cells = [c.strip() for c in raw.strip().strip("|").split("|")]
            key = cells[0].strip("`")
            if not KEY_RE.fullmatch(key) or key == "KEY":
                continue
            if len(cells) != 3:
                sys.exit("ERROR %s:%d: expected 3 cells, got %d" % (rel(path), n, len(cells)))
            rows.append((key, cells[1], cells[2], n))
    return rows


def placeholders(text):
    ## %% is a literal percent, not a placeholder.
    return PLACEHOLDER_RE.findall(text.replace("%%", ""))


def po_escape(text):
    return (text.replace("\\", "\\\\").replace('"', '\\"')
            .replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r"))


def main():
    errors = 0
    entries = {}   # key -> [catalan, english, source file]
    order = []     # first-seen order of the keys
    same_dups = 0
    diff_dups = 0
    counts = []
    for source in SOURCES:
        path = os.path.join(ROOT, source)
        if not os.path.exists(path):
            print("SKIPPED (missing): %s" % source)
            continue
        rows = parse_table(path)
        counts.append("%s %d" % (os.path.basename(source), len(rows)))
        for key, ca, en, _ in rows:
            if key in entries:
                old_ca, old_en, old_src = entries[key]
                if (old_ca, old_en) == (ca, en):
                    same_dups += 1
                else:
                    diff_dups += 1
                    print("DUPLICATE %s with different text: %s says %r, %s says %r; keeping %s"
                          % (key, os.path.basename(old_src), old_en, os.path.basename(source), en,
                             os.path.basename(source)))
            else:
                order.append(key)
            entries[key] = [ca, en, source]

    fixed = 0
    for key, (old, new) in EN_FIXES.items():
        if key not in entries:
            print("ERROR English fix for unknown key %s" % key)
            errors += 1
        elif entries[key][1] != old:
            print("ERROR English fix for %s does not match the table: has %r, expected %r"
                  % (key, entries[key][1], old))
            errors += 1
        else:
            entries[key][1] = new
            fixed += 1

    mismatches = 0
    for key in order:
        ca, en, _ = entries[key]
        if not ca or not en:
            print("ERROR empty text for %s" % key)
            errors += 1
        if placeholders(ca) != placeholders(en):
            mismatches += 1
            print("PLACEHOLDER MISMATCH %s: catalan %s, english %s"
                  % (key, placeholders(ca), placeholders(en)))

    for lang, idx in (("en", 1), ("ca", 0)):
        out = os.path.join(ROOT, "i18n", lang + ".po")
        with open(out, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(HEADER.format(lang=lang))
            for key in order:
                fh.write('msgid "%s"\nmsgstr "%s"\n\n' % (po_escape(key), po_escape(entries[key][idx])))
        print("WROTE %s (%d entries)" % (rel(out), len(order)))

    print("KEYS: %d (%s)" % (len(order), ", ".join(counts)))
    print("DUPLICATES: %d with the same text, %d with different text" % (same_dups, diff_dups))
    print("ENGLISH FIXES applied: %d of %d" % (fixed, len(EN_FIXES)))
    print("PLACEHOLDER MISMATCHES: %d" % mismatches)
    print("ERRORS: %d" % errors)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
