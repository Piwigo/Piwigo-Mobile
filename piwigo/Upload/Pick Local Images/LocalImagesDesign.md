# LocalImagesViewController redesign: design note

Status: proposal, based on `Spikes/LocalImagesLayout` (synthetic benchmarks) and `Probe/PhotoKitProbe.swift`
(on-device measurements). Nothing in the app has been changed.

## 1. Goals and constraints

- Present the assets of an album, sorted by creation date (newest first or oldest first), optionally grouped by
  day, week or month, for libraries of 100,000 to 1,000,000+ assets. Deployment target is iOS 15.5.
- Section header: Select/Deselect button, date range, location from the first 10 assets.
- Thumbnails show a play icon (video), the Piwigo logo (already uploaded), a checkmark (selected), an activity
  indicator (queued) and a progress bar (uploading).
- Opening the view and switching grouping must feel immediate; the main thread must never wait on PhotoKit for more
  than a batch.

## 2. What was measured

iPad 11" Pro, iOS 26.7, 126,386 assets (about 100k synthetic photos dated 1980–1998 plus real ones), thermal state 0,
several runs within 5%. **iPhone numbers are not measured and will be slower.**

| Measure | Result |
|---|---|
| Fetch as the controller does it (sorted, no predicate) | 345–420 ms (unsorted 150 ms) |
| Same fetch with a `mediaType` predicate | 2.7–3.8 s: never add a media predicate |
| PhotoKit loading unit | batches of 200 assets, about 10 ms per cold batch, 1.1 µs per read inside a batch |
| Random read of a cold asset | about 10 ms |
| Full pass reading every creation date | 7.0–8.0 s (about 58 µs per asset) |
| Full pass reading `localIdentifier` instead | +4 µs per asset (the cost is creating the asset) |
| Current single pass (day + week + month together) | 7.6–8.4 s; calendar work is 0.5 µs per asset |
| The same pass on 2 threads, joined | 5.0–5.5 s, identical sections, memory neutral (more threads: no gain) |
| Galloping / binary search on dates | 6.4–7.9 s: no better than a full pass (sections touch nearly every batch) |
| Count query on a date range (no asset created) | 3.0–3.3 ms flat, not parallelisable |
| Boundary index from a count query | `count(creationDate >= start)`, verified 40/40 |
| Fetch of one month's assets (date predicate, sorted) | 3.4–5.5 ms + about 10 ms for its first batch |
| Diffable apply by diff, 300k items | 2–13 s |
| `applySnapshotUsingReloadData`, 300k items | about 1 ms |
| Memory (`phys_footprint`) of a full pass | iPad iOS 26.7, 126k assets: peak +3 to +14 MB. **iPhone 16 Pro iOS 27.2, 104k assets: +140 to +220 MB per pass (1.4–2 KB per asset; 2.3 KB at 4.3k assets), still counted after the result is released and reused by the next pass.** It scales with the library on the iPhone: extrapolated, 1M assets would be 1.4–2 GB (unverified) |
| iPhone 16 Pro, iOS 27.2, **4,322 assets** | fetch 28 ms; full pass 56 ms (13 µs per asset); two-thread pass 32 ms; count query 1.2 ms; first read at a random spot 2.4 ms; second pass on the same result 0.6 µs per read (the whole library fits the result's cache) |
| iPhone 16 Pro, iOS 27.2, **104,322 assets** (two runs, thermal 0 and 1) | fetch 140–184 ms; random read 3.3 ms; cold batch 3.6–4.5 ms; full pass 1.75–1.80 s (16.7 µs per asset); app single pass 1.72 s; two-thread pass 0.96–0.98 s (−44%); 4 and 8 threads no better (sometimes worse); count query 1.4–1.5 ms; month fetch 1.7 ms; count queries for all calendar periods over the 46-year span: month 0.85 s, week 3.5 s, day 25 s |

Count queries cost in proportion to the calendar span, not the number of assets. For a typical 15-year library:
month about 0.6 s, week about 2.6 s, day about 18 s. The pass costs about 58 µs per asset whatever the span
(7.6 s at 126k, about 1 minute at 1M).

## 3. Architecture

### Data and identity

- One `PHFetchResult` per fetch generation, sorted by `creationDate`, exactly as today (no predicate).
- Item identifier: the asset's **position** (`Int`), valid for one generation. A PhotoLibrary change creates a new
  generation and a new snapshot. Section and offset map to a position through one array of section ranges
  (`LayoutMapper` in the spike); reversing the order only swaps the mapping.
- Collection view: always `applySnapshotUsingReloadData` (or a plain `UICollectionViewDataSource` reading one immutable
  layout value; the spike shows a diff-based apply is unusable at this size). Keep the first visible position and its
  offset, and restore them after a reload.

### Building the layouts

At open, build **only the selected grouping**:

| Selected grouping | Method at open | Cost (typical library) |
|---|---|---|
| None | one section `0..<count` | free |
| Month | count queries, one per calendar month | about 0.6 s |
| Week | count queries, one per calendar week | about 2.6 s |
| Day | the single pass on **two threads** (cuts aligned on 200-asset batches, chunks joined) | about 5 s at 126k |

**Choose by estimated cost, not by grouping.** Count queries cost about 1.2 ms (iPhone, 4k assets) to 3.1 ms (iPad,
126k assets) per calendar period, so they lose by a factor of ten on a small library (4,322 assets: month 0.68 s over
a 46-year span, against 0.057 s for the whole pass, which also delivers all three groupings and the identifiers). Use
the pass at open when `count` is below a threshold, and count queries for month and week only above it. On an iPhone 16 Pro
with 104k assets the two-thread pass takes about 1.0 s and delivers everything, against 0.85 s for the month
queries (about 0.3 s over a typical 15-year span), 3.5 s for week (about 1.1 s) and 25 s for day (about 8 s). So on a
current iPhone count queries only pay off beyond roughly 100k assets for month, 300k for week, and 1M+ for day
(pass cost is about 9 µs per asset on two threads, count queries are flat per calendar period). Older devices are
slower on both sides and the threshold is lower there; it is unmeasured. **A first version can use the two-thread pass
alone**: it is simple, correct and tested, and count queries can be added if libraries beyond 300k assets turn out to
be common.
Both costs are known at open: `count` from the fetch, the number of periods from the dates of the first and last asset.

The single pass yields day, week and month together, and the identifier array of section 5. Therefore:

- If the selected grouping is day: the pass at open delivers all three groupings, nothing is left to build.
- If it is month or week: after the count queries, start the same two-thread pass in the background. It delivers
  the other groupings and the identifier array. Switching grouping before it is done shows the existing HUD until the
  layout is ready; afterwards switching is immediate (a cached layout swapped in, then `reloadData`).
- A layout is immutable and cached per fetch generation, with a generation token: a result for an old generation is
  dropped; a new PHChange cancels the background job.
- Use `.yearForWeekOfYear` (not `.year`) with `.weekOfYear`: the current code appears to split a week at New Year
  (1,035 week sections where an interval-based layout finds 1,023). Verify.

### The pass runs in windows

A plain pass on one `PHFetchResult` makes PhotoKit keep about 2.3 KB per asset (150 MB at 104k assets on an iPhone
with iOS 27.2). Run the pass in date windows instead, each on its own fetch result that is released after use:

1. Count the assets per calendar year with count queries (about 46 × 1.4 ms). A year above about 10,000 assets is split
   into months the same way (and a month into days if ever needed), so the peak is bounded by the largest window
   (about 25 MB) whatever the library size.
2. The counts give each window's size and the offset of its first asset in the global order. Section ranges follow
   from the windows; the global `PHFetchResult` still serves the cells (equal creation dates cannot cause a
   mismatch, ties always fall in the same section).
3. Each window is fetched sorted, its dates are read in blocks of 200 inside an `autoreleasepool`, and day, week and
   month sections are computed as in the current pass.
4. Two threads take halves of the windows; the straddling sections (a week across New Year) are joined with the
   existing, tested `join`.

Measured (iPhone 16 Pro, 104k assets): per-year windows 1.87 s warm, peak +15 MB, against 2.05 s and +150 MB for the
plain pass. The identifier array of section 5 is collected in the same windows.

Prototype: `Sources/LayoutSpike/WindowedPass.swift` (`planWindows`, `WindowCursor`, `windowedPass`, over small
`WindowedSource` / `DateWindow` protocols; the PhotoKit adapter is in the probe). It reuses the tested `appPass` and
`join`. Tests (`WindowedPassTests`, 10 cases, synthetic source with query/fetch/live-asset instrumentation): identical to
the serial pass for window limits of 3 to 1,000,000 assets and 1 to 7 threads; plan invariants (contiguous, descending,
bounded unless a single day, one query per year unless a year is split); a small library is one window and costs no query;
live assets never exceed threads × largest window and every window is released; every window fetched once; empty and
single-asset libraries; one giant day; assets exactly on and one second before month starts; a 25-year empty gap. Two
deliberate bugs (a join that never merges, a cursor that keeps windows alive) are caught by 58 and 3 failures.
Measured on an iPhone 16 Pro, iOS 27.2, 104,322 assets (Run, then Memory test in a fresh process):

| | Time | Memory peak |
|---|---|---|
| Plan: 31 windows (largest 6,531 assets), 47 count queries | 80–92 ms | +2 MB |
| Windowed pass, 1 thread | 1.47–1.84 s | +14 MB |
| Windowed pass, 2 threads | 0.95–1.18 s | +18 to +42 MB |
| Plain pass, serial (as the app does it) | 1.44–2.29 s | +128 to +266 MB |
| Plain pass, 2 threads | 1.07 s | +152 MB |

Results identical to the serial pass in every run. Open cost for all three groupings at 104k assets: about 1.0–1.3 s
including the plan, with a memory peak about 4 to 6 times lower than the plain pass; the time is the same as the plain
two-thread pass. To bound the peak further, lower `maxWindow` (5,000 would also split the 6,531-asset year into months for
about 12 more count queries); the probe takes `--maxwindow=N` as a launch argument (Edit Scheme ▸ Arguments Passed On
Launch works on a device).

### Cell content

- The asset for a position comes from a small windowed cache (blocks of 200) filled by
  `UICollectionViewDataSourcePrefetching` on a background queue, with a synchronous `object(at:)` fallback.
  PhotoKit keeps no cache across passes, so the app must retain what it prefetches.
- Header date range and location are computed when the header appears and cached by section range; geocoding is
  cancelled when the header leaves.
- `canPerform(.delete)` is evaluated when the context menu opens, never cached for all assets.

## 4. Upload requests and "uploaded" state

- Source of truth: the `Upload` requests in Core Data, keyed by `localIdentifier`. Keep a
  `[localIdentifier: (state, progress)]` dictionary on the main actor, updated from the upload controller.
- A cell reads its state from that dictionary when it is configured (its asset's `localIdentifier`).
  A state or progress change updates the visible cells only; nothing is rebuilt.

## 5. Selection ("select this section")

Problem: "select this section" must skip assets already uploaded or queued, and a section can hold 20,000 assets
(or 100,000 with no grouping). Reading them one by one costs about 60 µs each (1.2 s for 20k, 6 s for 100k).

Design:

- **Identifier array.** The background pass also records `localIdentifier` for every position
  (`ids[position]`, about +4 µs per asset, so +0.5 s at 126k; about 10 MB at 126k, about 80 MB at 1M; a compact
  form (UUID bytes) is possible if needed). It is built once per generation, in parallel with the groupings.
- **Selection as ranges.** The selection is an `IndexSet` of positions. "Select this section" inserts the
  section's range: O(1), no asset is read.
- **Queued positions.** Once `ids` exists, `queuedPositions = { i | ids[i] ∈ queuedSet }` is one in-memory scan
  (about 126k hash lookups, tens of ms) and is recomputed when uploads change. The effective selection is
  `selection − queuedPositions` (unless re-upload is allowed). It gives the "N selected" count without touching
  PhotoKit.
- **Before `ids` exists** (the first seconds after opening): selection ranges still work; exclusion of queued assets
  is applied lazily when the user starts the upload, by reading the selected assets, and the count shows the
  range size. The queued positions can alternatively be resolved by date: one fetch of the queued assets by identifier,
  then `count(creationDate > date)` plus tie handling (about 6 ms each; to be measured as an alternative).
- Remapping the selection after a PHChange: use `removedIndexes` / `insertedIndexes` of the change details, or
  convert to identifiers and back (cost proportional to the selection).

## 6. Why items are identified by position, not by `localIdentifier`

Considered: use `localIdentifier` as the diffable item identifier, so that the upload cache can be built in
parallel with the groupings. Rejected because:

1. It requires every identifier before the first snapshot, that is a full pass (7–8 s at 126k, about 5 s on two
   threads) for **every** grouping. That cancels the count-query advantage (0.6 s for month, 2.6 s for week) and
   delays opening.
2. Identity stability buys nothing here: structural changes use `reloadData` because a diff of 126k+ items costs
   seconds, with strings as much as with integers.
3. It costs memory and hashing: strings (about 22 MB at 300k in a snapshot) against 8-byte integers (about 10 MB).
4. It does not speed up the upload cache, which concerns the few upload requests, not all assets. What speeds it up
   is the in-memory `ids` array of section 5, built by the pass that runs anyway.

Position identifiers plus an `ids` array give the same lookups by identifier (O(n) once, then O(1)) while the
collection opens on count queries.

## 7. Risks and open points

- Not measured on an iPhone (the iPhone 6s used by one user cannot be reached with the current Xcode). Expect
  slower passes; count queries are per-call IPC and should scale less.
- **Memory of a full pass on iOS 27 (iPhone): measured, mitigated by windows.** A plain pass over 104k assets adds
  about 150 MB (2.3 KB per asset) that `malloc_zone_pressure_relief` does not return; later passes reuse it and the
  footprint falls only gradually. In a fresh process, the same pass in windows (one fetch result per year, released
  after use) peaks at +15 MB and per month at +1 MB, in the same time once warm (1.87 s against 2.05 s; per-month
  windows cost about 50% more). See "The pass runs in windows" in section 3. The iPad on iOS 26.7 showed almost
  nothing, so this is OS- or device-specific.
- Contention: a background pass slows concurrent cell reads (a cold batch is about 10 ms alone). Measure the latency of
  cell reads during the pass; if bad, lower the pass priority, throttle it, or prefetch further ahead.
- Alternative to indexes of queued assets: a count query with `localIdentifier IN %@` inside a date range (unmeasured).
- Assets whose `creationDate` is nil: the current code substitutes `Date()`; decide where they sort and how the count
  queries treat them.
- Equal creation dates are fine for calendar boundaries (boundaries are calendar starts, not assets).
- A PHChange arriving while a background pass runs: cancel, start a new generation, keep the old layout on screen
  until the new one is ready.
- The synthetic library has a 1998–2025 gap and uniform dates; section sizes in real libraries are burstier.

## 8. Verification plan

- Unit tests (SwiftPM, synthetic dates): layout builders against each other; chunk join for every cut position
  (`AppPassTests`); mapper round trips in both orders; selection remapping; queued-position scans.
- Probe on device for any new strategy, in a Release build, thermal state 0, two runs, with `phys_footprint` peak.
- Instruments (Time Profiler, Allocations) on the new controller with a 100k-asset library and a 1M-asset library
  (generate with a filler app).

## 9. Suggested order of work

1. Layout module (builders, mapper, pass with join) in a package, with the tests above.
2. New controller on position identifiers, reading from the asset window cache; no groupings yet except none.
3. Month/week count-query layouts and the two-thread day pass; background completion and cached switching.
4. Upload dictionary and visible-cell updates.
5. `ids` array and selection ranges with queued exclusion.
6. PHChange handling and selection remapping.
7. Remove `indexedUploadsInQueue`, the three `IndexSet` arrays and the `BlockOperation`s.


## 10. Implementation (22 October 2026)

Done in `piwigo/Upload/Pick Local Images/` and `PwgUploadKit/Sources/LocalImages/`. Where it differs from the plan above:

- **Plain data source, not diffable.** The collection view reads one immutable `PhotoLibraryLayout` (section ranges and
  order), swapped on the main thread, followed by `reloadData()`. Same atomicity as a snapshot, no snapshot to build
  (2 s for 2,272 day sections) and no diff (13 s at 300k items). Items are identified by their position.
- **No identifier array.** The positions of the images that have an upload request are found in the background with
  `PHAsset.fetchAssets(withLocalIdentifiers:)` and `PHFetchResult.index(of:)` (0.1 ms each in the probe), which avoids
  keeping a string per asset. `PhotoLibraryAssets.positions(ofAssetsWithIdentifiers:)`.
- **Windowed two-thread pass** (`PhotoLibraryLayoutBuilder`): windows of at most 5,000 assets, two threads, on dispatch
  threads (not the cooperative pool), cancellable. Falls back to one serial pass when the windows do not cover the album
  (assets without creation date). Week sections still compare `.year` and `.weekOfYear`, as before.
- **Selection** is `PhotoLibrarySelection`, an `IndexSet` of positions; Select All inserts one range minus the queued
  positions, whatever the size of the section. The state of a Select button is computed, nothing is stored per section.
- **Upload states** are a `[localIdentifier: state]` dictionary kept up to date from the fetched results controller;
  cells read it instead of scanning the upload requests.
- **Photo Library changes** prepare the new sections, upload positions and remapped selection in the background and swap
  them in at once (HUD meanwhile), so the collection view never sees half of them.
- **Prefetching** reads the assets of the cells about to appear in the background into an `NSCache`.
- The sections of the three groupings are built when the view opens, in the background; the images are shown at once
  (not grouped). Choosing a grouping before its sections are ready waits behind the HUD.

Verified: 32 package tests (layout mapping in both orders, selection arithmetic, grouping against a reference, chunk join
for every cut, windowed pass for every window size and thread count, cancellation, memory bound; the join test fails on
a deliberately broken join); app builds in Debug and Release without warnings in the changed files; a scratch copy of the
app driven by script in the simulator against real PhotoKit (windows of 8 assets over 324 dated photos): sections
identical to the former algorithm for day, week and month; grouping and order changes; selecting a section; insertion of
a photo with the selection kept on the same photos; upload requests created in Core Data: states, queued positions,
Select All skipping them, deselect on insertion, re-upload, deletion.

Not verified: a library of 100k+ photos on a device (time to open, memory, scrolling, prefetch), real uploads through the
upload manager, context menus, rotation, the iPad layouts, the macOS Catalyst build. Batch deletes of upload requests do
not reach the fetched results controller (as before): the view learns of them at the next change.
