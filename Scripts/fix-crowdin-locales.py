#!/usr/bin/env python3
"""Rewrite the locale codes Crowdin uses in exported String Catalogs.

Crowdin keys the `localizations` object of an exported .xcstrings by its
`osx_locale` placeholder, which for Portuguese is `pt` — while this project,
its `knownRegions` and its .lproj folders use `pt-PT` (on Apple platforms `pt`
is the legacy code for Brazilian Portuguese). Crowdin's Language Mapping is
ignored for String Catalogs, so the codes have to be fixed after download.

Run it on the freshly downloaded catalogs, before opening them in Xcode:

    fix-crowdin-locales.py [path ...] [--write]

With no path, every .xcstrings in the repository is checked. Without --write
the script only reports what it would change. Catalogs are re-emitted in
Xcode's own JSON layout (2-space indent, " : " separator, unescaped UTF-8,
localizations sorted by code), so an already-correct file is left untouched
byte for byte.
"""
import json, os, sys, collections

# Crowdin code -> code used by this project.
LOCALE_MAP = {
    "pt": "pt-PT",
}

SKIP_DIRS = {".git", "DerivedData", "build", ".build"}


def catalogs(paths):
    """Yield .xcstrings paths from the given files/directories."""
    for path in paths:
        if os.path.isfile(path):
            yield path
            continue
        for root, dirs, files in os.walk(path):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            for name in sorted(files):
                if name.endswith(".xcstrings"):
                    yield os.path.join(root, name)


def fix(path, write):
    """Remap the locale codes of one catalog. Returns the number of entries changed."""
    raw = open(path, encoding="utf-8").read()
    catalog = json.loads(raw, object_pairs_hook=collections.OrderedDict)

    changed = 0
    for key, entry in catalog.get("strings", {}).items():
        localizations = entry.get("localizations")
        if not localizations:
            continue
        hits = [code for code in LOCALE_MAP if code in localizations]
        if not hits:
            continue
        for code in hits:
            target = LOCALE_MAP[code]
            if target in localizations:
                sys.exit(f"{path}: '{key}' has both '{code}' and '{target}'")
            localizations[target] = localizations.pop(code)
        entry["localizations"] = collections.OrderedDict(sorted(localizations.items()))
        changed += 1

    if changed and write:
        out = json.dumps(catalog, indent=2, separators=(",", " : "), ensure_ascii=False)
        if raw.endswith("\n"):
            out += "\n"
        open(path, "w", encoding="utf-8").write(out)
    return changed


def main(argv):
    write = "--write" in argv
    paths = [a for a in argv if not a.startswith("--")] or ["."]

    total = 0
    for path in catalogs(paths):
        changed = fix(path, write)
        if changed:
            total += changed
            print(f"{'fixed' if write else 'would fix'} {changed:5d}  {path}")

    codes = ", ".join(f"{k} -> {v}" for k, v in LOCALE_MAP.items())
    if not total:
        print(f"nothing to do ({codes})")
    elif not write:
        print(f"\n{total} entries to remap ({codes}); re-run with --write to apply")


if __name__ == "__main__":
    main(sys.argv[1:])
