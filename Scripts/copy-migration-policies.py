#!/usr/bin/env python3
"""Copy entityMigrationPolicyClassName values from one xcmapping.xml into another.

Use after regenerating a mapping model in Xcode: Xcode writes fresh model
snapshots (and therefore fresh version hashes) but drops the migration policy
class names you had set by hand. This re-applies them, matched on the
(source entity, destination entity) pair.

    copy-migration-policies.py <old xcmapping.xml> <new xcmapping.xml> [--write]
"""
import re, sys

OBJ = re.compile(r'<object type="XDDEVENTITYMAPPING" id="\w+">(.*?)</object>', re.S)
ATTR = lambda n: re.compile(r'<attribute name="%s" type="string">([^<]*)</attribute>' % n)


def entity_mappings(xml):
    """(source, destination) -> (policy or None, span of the object body)."""
    out = {}
    for m in OBJ.finditer(xml):
        body = m.group(1)
        src = ATTR('sourcename').search(body)
        dst = ATTR('destinationname').search(body)
        if not src or not dst:
            continue
        pol = ATTR('migrationpolicyclassname').search(body)
        out[(src.group(1), dst.group(1))] = (
            pol.group(1) if pol else None,
            (m.start(1), m.end(1)),
        )
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    write = '--write' in sys.argv
    if len(args) != 2:
        sys.exit(__doc__)
    old_path, new_path = args
    old_xml = open(old_path, encoding='utf-8').read()
    new_xml = open(new_path, encoding='utf-8').read()

    old = entity_mappings(old_xml)
    new = entity_mappings(new_xml)

    # Apply back-to-front so earlier spans stay valid.
    edits, unchanged, missing = [], [], []
    for key, (new_pol, span) in sorted(new.items(), key=lambda kv: -kv[1][1][0]):
        old_pol = old.get(key, (None, None))[0]
        if old_pol is None:
            missing.append(key)
        elif old_pol == new_pol:
            unchanged.append((key, new_pol))
        else:
            edits.append((key, old_pol, new_pol, span))

    out = new_xml
    for (src, dst), old_pol, new_pol, (a, b) in edits:
        body = out[a:b]
        line = '        <attribute name="migrationpolicyclassname" type="string">%s</attribute>\n' % old_pol
        if new_pol is None:
            body = body.replace('\n', '\n' + line, 1)          # insert as first attribute
        else:
            body = ATTR('migrationpolicyclassname').sub(line.strip(), body, count=1)
        out = out[:a] + body + out[b:]
        print('  set   %s -> %s : %s%s' % (src, dst, old_pol,
              '' if new_pol is None else ' (was %s)' % new_pol))

    for (src, dst), pol in unchanged:
        print('  same  %s -> %s : %s' % (src, dst, pol or 'no policy'))
    for src, dst in missing:
        print('  KEEP  %s -> %s : no policy in %s, left as-is' % (src, dst, old_path.split('/')[-1]))

    dropped = set(old) - set(new)
    for src, dst in sorted(dropped):
        print('  GONE  %s -> %s : present in old mapping model, absent in new' % (src, dst))

    print('\n%d policy name(s) to copy, %d already correct.' % (len(edits), len(unchanged)))
    if write and edits:
        open(new_path, 'w', encoding='utf-8').write(out)
        print('Wrote %s' % new_path)
    elif edits:
        print('Dry run — pass --write to apply.')


if __name__ == '__main__':
    main()
