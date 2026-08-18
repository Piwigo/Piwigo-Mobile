# Scripts

Maintenance tools for the PwgCacheKit Core Data migration chain.

## Why these exist

A `.xcmappingmodel` embeds an NSKeyedArchiver snapshot of its source and
destination models. Core Data selects it by comparing the entity version hashes
in that snapshot against the compiled `.mom` files, so editing a
`.xcdatamodel` after the mapping model was generated leaves the mapping model
**orphaned**: `NSMappingModel(from:forSourceModel:destinationModel:)` stops
finding it and the step silently degrades to `NSMappingModel.inferredMappingModel`.

Nothing warns at build time and nothing fails at runtime — the migration still
"works", it just runs without the `NSEntityMigrationPolicy` classes, so there is
no progress reporting, no cancellation, and no custom attribute conversion.

Three steps were orphaned this way. On `0H → 0J` it cost users data:
`UploadToUploadMigrationPolicy_0H_to_0J` converts `prefixFileNameBeforeUpload`
and `defaultPrefix` into `fileNamePrefixEncodedActions`, and it never ran, so
upgraders from v3.3 lost their filename-prefix settings.

`PwgCacheKit/Tests/MigrationChainTests.swift` now fails the build when a step
degrades. These scripts diagnose and repair.

## audit-mapping-models.sh

Compiles every model version with `momc` and every mapping model with `mapc`,
then reports which mapping models no longer match the versions they name — and
which entity drifted. Needs no simulator, so it is the faster tool when a step
goes red.

```bash
Scripts/audit-mapping-models.sh
```

Exits non-zero if anything is orphaned.

## copy-migration-policies.py

Xcode drops every `entityMigrationPolicyClassName` when it rewrites a mapping
model, and regenerating in place overwrites the file you needed to copy them
from — recover the previous version with `git show HEAD:<path>` first. Matches
entity mappings on their (source, destination) entity pair.

```bash
python3 Scripts/copy-migration-policies.py <old xcmapping.xml> <new xcmapping.xml>          # dry run
python3 Scripts/copy-migration-policies.py <old xcmapping.xml> <new xcmapping.xml> --write
```

## transplant-model-snapshot.py

Repairs an orphaned mapping model **without Xcode**, when only the hashes
drifted and the entity mappings themselves are still correct.

`mapc` derives the version hashes purely from the embedded snapshots, and those
blobs are self-contained — entity mappings reference entities by name only. So a
current snapshot of a model version can be lifted from any other mapping model
that already embeds one. It refuses to run if the two `modelpath` fields name
different versions.

```bash
# Refresh 0N→0O's stale 0O snapshot from the 0O→0P mapping model's source side.
python3 Scripts/transplant-model-snapshot.py \
    PwgCacheKit/Sources/MigrationTools/MappingModel_0O_to_0P/Mapping_Model_0O_to_0P.xcmappingmodel/xcmapping.xml source \
    PwgCacheKit/Sources/MigrationTools/MappingModel_0N_to_0O/Mapping_Model_0N_to_0O.xcmappingmodel/xcmapping.xml destination \
    --write
```

This fixes hashes, not content. If a model edit **added or removed** an
attribute, the mapping model needs a new entity mapping for it, and only Xcode
can produce that. It also needs a donor: a brand-new model version has none, so
the step that introduces it must go through Xcode.

## Regenerating a mapping model in Xcode

The assistant lists nothing from `piwigo.xcodeproj`, which holds zero
`.xcdatamodel` file references — the models live inside the local SwiftPM
package. Open `PwgCacheKit/Package.swift` on its own, then
File > New > File > Mapping Model.

`sourcemodelpath` / `destinationmodelpath` are cosmetic: `mapc` produces a
byte-identical `.cdm` whatever they say.

If Xcode crashes on opening the package, it is restoring an editor for a mapping
model that no longer exists. Quit Xcode and delete
`PwgCacheKit/.swiftpm/xcode/package.xcworkspace/xcuserdata/*.xcuserdatad/UserInterfaceState.xcuserstate`.

## Running the tests

Local SwiftPM test targets cannot run from `piwigo.xcodeproj`:

```bash
cd PwgCacheKit && xcodebuild test -scheme PwgCacheKit -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```
