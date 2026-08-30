#!/bin/zsh
#
#  audit-mapping-models.sh
#  Piwigo-Mobile
#
#  Reports whether each .xcmappingmodel in PwgCacheKit still matches the model
#  versions it names, and names the entities that drifted when it does not.
#
#  A mapping model embeds a snapshot of its source and destination models, and
#  Core Data selects it by comparing the entity version hashes in that snapshot
#  against the compiled models. Editing a .xcdatamodel after the mapping model
#  was generated leaves it "orphaned": NSMappingModel(from:forSourceModel:
#  destinationModel:) stops finding it and the step silently degrades to
#  lightweight inference, losing the migration policies' progress reporting and
#  cancellation — with no build warning and no runtime error.
#
#  Unlike the PwgCacheKitTests suite, this needs no simulator and reports which
#  entity drifted, so it is the tool to reach for when a step goes red.
#
#    Scripts/audit-mapping-models.sh [repo root]
#
set -e

REPO="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
PKG="$REPO/PwgCacheKit"
[[ -d "$PKG/Sources/DataModel.xcdatamodeld" ]] || { echo "not a Piwigo-Mobile checkout: $REPO" >&2; exit 1 }

MOMC=$(xcrun --find momc)
MAPC=$(xcrun --find mapc)
SDK=$(xcrun --show-sdk-path --sdk macosx)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/mom" "$WORK/cdm"

for m in "$PKG/Sources/DataModel.xcdatamodeld"/*.xcdatamodel; do
  "$MOMC" --sdkroot "$SDK" --macosx-deployment-target 14.0 --module PwgCacheKit \
          "$m" "$WORK/mom/$(basename "$m" .xcdatamodel).mom" >/dev/null 2>&1
done

for mm in "$PKG/Sources/MigrationTools"/*/*.xcmappingmodel; do
  name=$(basename "$mm" .xcmappingmodel)
  "$MAPC" "$mm" "$WORK/cdm/$name.cdm" >/dev/null 2>&1 || echo "mapc failed: $mm" >&2
  # Record which model versions the mapping model claims, so the comparison
  # does not depend on the migration chain in DataMigrationVersion.swift.
  python3 - "$mm/xcmapping.xml" "$WORK/cdm/$name.paths" <<'PY'
import re, sys
xml = open(sys.argv[1], encoding='utf-8').read()
out = []
for which in ('source', 'destination'):
    m = re.search(r'<attribute name="%smodelpath" type="string">([^<]*)</attribute>' % which, xml)
    out.append(m.group(1).rsplit('/', 1)[-1].replace('.xcdatamodel', '') if m else '?')
open(sys.argv[2], 'w').write('\n'.join(out) + '\n')
PY
done

cat > "$WORK/audit.swift" <<'SWIFT'
import Foundation
import CoreData

let work = CommandLine.arguments[1]
let fm = FileManager.default

func hex(_ d: Data?) -> String {
    (d ?? Data()).prefix(8).map { String(format: "%02x", $0) }.joined()
}

var models: [String: NSManagedObjectModel] = [:]   // "DataModel 0J (Group)" -> model
for f in (try? fm.contentsOfDirectory(atPath: work + "/mom")) ?? [] where f.hasSuffix(".mom") {
    let name = String(f.dropLast(4))
    if let m = NSManagedObjectModel(contentsOf: URL(fileURLWithPath: work + "/mom/" + f)) {
        models[name] = m
    }
}

let names = ((try? fm.contentsOfDirectory(atPath: work + "/cdm")) ?? [])
    .filter { $0.hasSuffix(".cdm") }.map { String($0.dropLast(4)) }.sorted()

var orphaned = 0
for name in names {
    guard let mm = NSMappingModel(contentsOf: URL(fileURLWithPath: "\(work)/cdm/\(name).cdm")),
          let claimed = try? String(contentsOfFile: "\(work)/cdm/\(name).paths", encoding: .utf8)
    else { print("?? \(name): could not load"); orphaned += 1; continue }

    let versions = claimed.split(separator: "\n").map(String.init)
    guard versions.count == 2, let src = models[versions[0]], let dst = models[versions[1]] else {
        print("?? \(name): names model version(s) not on disk — \(versions.joined(separator: " -> "))")
        orphaned += 1
        continue
    }

    let srcH = src.entityVersionHashesByName, dstH = dst.entityVersionHashesByName
    var drifted: [String] = []
    for em in mm.entityMappings.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }) {
        if let n = em.sourceEntityName, let h = em.sourceEntityVersionHash, srcH[n] != h {
            drifted.append("source \(n) (mapping \(hex(h))… vs model \(hex(srcH[n]))…)")
        }
        if let n = em.destinationEntityName, let h = em.destinationEntityVersionHash, dstH[n] != h {
            drifted.append("dest \(n) (mapping \(hex(h))… vs model \(hex(dstH[n]))…)")
        }
    }

    let policies = mm.entityMappings.compactMap { $0.entityMigrationPolicyClassName }.count
    if drifted.isEmpty {
        print("ok        \(name): \(policies)/\(mm.entityMappings.count) entity mappings have a policy")
    } else {
        orphaned += 1
        print("ORPHANED  \(name): \(mm.entityMappings.count) entity mappings, \(policies) with a policy")
        for d in drifted { print("             drifted: \(d)") }
    }
}

print("")
if orphaned == 0 {
    print("All \(names.count) mapping models match the model versions they name.")
} else {
    print("\(orphaned) of \(names.count) mapping models are orphaned and will be ignored at runtime.")
    print("Fix: regenerate in Xcode (File > New > File > Mapping Model) from the")
    print("PwgCacheKit package opened on its own, then restore the policy names with")
    print("Scripts/copy-migration-policies.py. If only the hashes drifted and the")
    print("entity mappings are still correct, Scripts/transplant-model-snapshot.py")
    print("can refresh the snapshot from another mapping model without Xcode.")
}
exit(orphaned == 0 ? 0 : 1)
SWIFT

xcrun swift -O "$WORK/audit.swift" "$WORK"
