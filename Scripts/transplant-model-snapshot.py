#!/usr/bin/env python3
"""Transplant an embedded model snapshot from one xcmapping.xml into another.

An .xcmappingmodel stores NSKeyedArchiver snapshots of its source and
destination models in `sourcemodeldata` / `destinationmodeldata`; mapc derives
the entity version hashes purely from those. When a model version is edited
after a mapping model was generated, the mapping model is orphaned. If some
OTHER mapping model already embeds a current snapshot of that same version,
its blob can be copied over instead of regenerating in Xcode.

  transplant-model-snapshot.py <donor.xml> <source|destination> \
                              <target.xml> <source|destination> [--write]
"""
import re, sys

def blob_re(which):
    return re.compile(r'(<attribute name="%smodeldata" type="binary">)(.*?)(</attribute>)' % which, re.S)

def path_re(which):
    return re.compile(r'(<attribute name="%smodelpath" type="string">)([^<]*)(</attribute>)' % which)

def main():
    pos = [a for a in sys.argv[1:] if not a.startswith('--')]
    write = '--write' in sys.argv
    if len(pos) != 4:
        sys.exit(__doc__)
    donor_p, donor_which, target_p, target_which = pos
    donor = open(donor_p, encoding='utf-8').read()
    target = open(target_p, encoding='utf-8').read()

    dm = blob_re(donor_which).search(donor)
    tm = blob_re(target_which).search(target)
    if not dm or not tm:
        sys.exit('could not locate %smodeldata / %smodeldata' % (donor_which, target_which))

    dpath = path_re(donor_which).search(donor)
    tpath = path_re(target_which).search(target)
    print('donor  %s model: %s' % (donor_which, dpath.group(2) if dpath else '?'))
    print('target %s model: %s' % (target_which, tpath.group(2) if tpath else '?'))
    if dpath and tpath and dpath.group(2) != tpath.group(2):
        print('\nREFUSING: the two snapshots are of different model versions.')
        sys.exit(1)
    if dm.group(2).strip() == tm.group(2).strip():
        print('\nSnapshots already identical — nothing to do.')
        return

    out = target[:tm.start(2)] + dm.group(2) + target[tm.end(2):]
    print('\nreplacing %d bytes of base64 with %d bytes' % (len(tm.group(2)), len(dm.group(2))))
    if write:
        open(target_p, 'w', encoding='utf-8').write(out)
        print('Wrote %s' % target_p)
    else:
        print('Dry run — pass --write to apply.')

if __name__ == '__main__':
    main()
