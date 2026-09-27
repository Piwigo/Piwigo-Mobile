#!/usr/bin/env python3
"""Sort property-list keys by the names Xcode's property list editor shows.

Xcode displays known keys under a readable name — CFBundleVersion as "Bundle
version", NSFaceIDUsageDescription as "Privacy - Face ID Usage Description" —
but lists them in file order. Sorting by raw key therefore looks shuffled in the
editor. This script sorts every dictionary by its display name instead, using
the structure definitions bundled with the selected Xcode (xcode-select -p):
the Info.plist schema for Info*.plist / *Info.plist, the Settings schema for
Root.plist. Keys without a display name, and plists matching no schema, sort
by raw key. Comparison ignores case; array order is preserved.

    sort-plists.py [path ...] [--write]

With no path, every tracked .plist outside Xcode-managed folders (xcuserdata,
xcshareddata) and fastlane is checked. Without --write the script only reports
what it would change. Files are re-emitted in Xcode's own XML layout, so an
already-sorted file is left untouched byte for byte.
"""
import fnmatch, os, plistlib, subprocess, sys
import xml.etree.ElementTree as ET

SCHEMA_FILES = [
    'PlugIns/DVTCorePlistStructDefs.dvtplugin/Contents/Resources/DVTCorePlistStructDefs.xcplugindata',
    'Frameworks/DVTiOSPlistStructDefs.framework/Versions/A/Resources/DVTiOSPlistStructDefs.xcplugindata',
]
EXCLUDED_DIRS = ('xcuserdata', 'xcshareddata', 'fastlane')

def load_schemas():
    """Returns [(filename patterns, {definition name: <definition> element})]."""
    developer = subprocess.run(['xcode-select', '-p'], capture_output=True, text=True, check=True).stdout.strip()
    contents = os.path.dirname(developer)

    def extensions(o):
        if isinstance(o, dict):
            for k, v in o.items():
                if k == '_DVTExtensionXML':
                    yield v
                else:
                    yield from extensions(v)
        elif isinstance(o, list):
            for v in o:
                yield from extensions(v)

    schemas = []
    for rel in SCHEMA_FILES:
        with open(os.path.join(contents, rel), 'rb') as f:
            data = plistlib.load(f)
        for xml in extensions(data):
            if 'point="com.apple.xcode.plist.structure-definition"' not in xml:
                continue
            root = ET.fromstring(xml)
            patterns = [e.get('pattern') for e in root.iter('filename')]
            if patterns:
                schemas.append((patterns, {d.get('name'): d for d in root.iter('definition')}))
    return schemas

class Sorter:
    def __init__(self, definitions):
        self.definitions = definitions

    def dictionary_definition(self, class_name, value):
        """Returns the Dictionary definition describing value, resolving variants
        (e.g. a Settings item chosen by its Type), or None."""
        d = self.definitions.get(class_name)
        if d is None:
            return None
        if d.get('className') == 'VariantDictionary':
            chosen = d.get('default')
            for variant in d.iter('variant'):
                vd = self.definitions.get(variant.get('className'))
                if vd is not None and value.get(vd.get('variantKey')) == vd.get('variantValue'):
                    chosen = variant.get('className')
                    break
            return self.dictionary_definition(chosen, value)
        return d if d.get('className') == 'Dictionary' else None

    def sort(self, value, class_name, element_class_name=None):
        if isinstance(value, list):
            if element_class_name is None:
                d = self.definitions.get(class_name)
                element_class_name = d.get('arrayElementClassName') if d is not None else None
            return [self.sort(v, element_class_name) for v in value]
        if not isinstance(value, dict):
            return value
        d = self.dictionary_definition(class_name, value)
        keys = {}
        if d is not None and d.find('dictionaryKeys') is not None:
            keys = {k.get('name'): k for k in d.find('dictionaryKeys').findall('key')}
        other_class_name = d.get('defaultDictionaryValueClassName') if d is not None else None

        def label(key):
            k = keys.get(key)
            return (k.get('localizedString') if k is not None else None) or key

        result = {}
        for key in sorted(value, key=lambda k: (label(k).casefold(), label(k), k)):
            k = keys.get(key)
            if k is not None:
                result[key] = self.sort(value[key], k.get('className'), k.get('arrayElementClassName'))
            else:
                result[key] = self.sort(value[key], other_class_name)
        return result

def default_paths():
    root = subprocess.run(['git', 'rev-parse', '--show-toplevel'], capture_output=True, text=True, check=True).stdout.strip()
    tracked = subprocess.run(['git', 'ls-files', '-z', '*.plist'], cwd=root, capture_output=True, text=True, check=True).stdout
    return [os.path.join(root, p) for p in tracked.split('\0')
            if p and not any(part in EXCLUDED_DIRS for part in p.split('/'))]

def main(argv):
    write = '--write' in argv
    paths = [a for a in argv if a != '--write'] or default_paths()
    schemas = load_schemas()
    changed = 0
    for path in paths:
        name = os.path.basename(path)
        definitions = next((d for patterns, d in schemas
                            if any(fnmatch.fnmatchcase(name, p) for p in patterns)), {})
        with open(path, 'rb') as f:
            original = f.read()
        sorted_data = plistlib.dumps(Sorter(definitions).sort(plistlib.loads(original), '_root_'), sort_keys=False)
        if sorted_data == original:
            continue
        changed += 1
        if write:
            with open(path, 'wb') as f:
                f.write(sorted_data)
            print(f'sorted: {path}')
        else:
            print(f'would sort: {path}')
    if not changed:
        print('All property lists are sorted.')

if __name__ == '__main__':
    main(sys.argv[1:])
