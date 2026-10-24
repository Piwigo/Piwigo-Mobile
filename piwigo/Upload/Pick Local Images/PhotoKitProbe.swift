//
//  PhotoKitProbe.swift
//  Throw-away probe for the LocalImagesViewController redesign: not part of the app.
//
//  Single-file iOS app (iOS 15+). To run it on a device:
//   1. Xcode ▸ File ▸ New ▸ Project ▸ iOS App (SwiftUI), any name, minimum iOS 15.
//   2. Delete the generated App and ContentView files, add this file.
//   3. Target ▸ Info ▸ add "Privacy - Photo Library Usage Description" (NSPhotoLibraryUsageDescription).
//   4. Run a Release build (Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Build Configuration ▸ Release)
//      on the device, unplugged from the debugger is not required. Keep the screen on.
//   5. Pick a collection (or All Photos), tap Run, and send back the log (Copy button).
//

import SwiftUI
import Combine
import Photos

// MARK: - App
@main
struct PhotoKitProbeApp: App {
    var body: some Scene { WindowGroup { ProbeView() } }
}

// MARK: - Probe
/// Largest window of the windowed pass; `--maxwindow=N` on the command line overrides it (to exercise splits on a small library).
let probeMaxWindow: Int = CommandLine.arguments.compactMap { $0.hasPrefix("--maxwindow=") ? Int($0.dropFirst(12)) : nil }.first ?? 10_000

final class Probe: ObservableObject {
    @Published var log = ""
    @Published var running = false
    @Published var collections: [(title: String, collection: PHAssetCollection?, estimate: Int)] = []

    func loadCollections() {
        var result: [(String, PHAssetCollection?, Int)] = [("All Photos", nil, -1)]
        for type in [PHAssetCollectionType.smartAlbum, .album] {
            let fetch = PHAssetCollection.fetchAssetCollections(with: type, subtype: .any, options: nil)
            fetch.enumerateObjects { c, _, _ in
                let n = c.estimatedAssetCount
                if n == NSNotFound || n > 0 { result.append((c.localizedTitle ?? "?", c, n == NSNotFound ? -1 : n)) }
            }
        }
        DispatchQueue.main.async { self.collections = result }
    }

    private func say(_ s: String) {
        print("PROBE \(s)")
        DispatchQueue.main.async { self.log += s + "\n" }
    }

    private func residentMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576 : 0
    }

    /// Memory footprint as iOS counts it for memory kills (phys_footprint), in MB.
    private func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
    }

    /// Peak footprint reached during the last timed block, and what it still held when the block ended (both vs. start).
    private var lastPeakMB = 0.0
    private var lastRetainedMB = 0.0
    private var memo: String { String(format: "peak %+.0f MB, kept %+.0f MB", lastPeakMB, lastRetainedMB) }

    /// Each timed block drains its own autorelease pool when it ends, as the controller's BlockOperation does,
    /// and its memory footprint is sampled every 10 ms on another thread.
    private func time<T>(_ block: () -> T) -> (T, Double) {
        let lock = NSLock()
        var peak = footprintMB(), stop = false
        let start = peak
        let sampler = Thread {
            while true {
                lock.lock(); let done = stop; if !done { peak = max(peak, self.footprintMB()) }; lock.unlock()
                if done { break }
                usleep(10_000)
            }
        }
        sampler.start()
        let t = CFAbsoluteTimeGetCurrent()
        let r = autoreleasepool { block() }
        let ms = (CFAbsoluteTimeGetCurrent() - t) * 1000
        let end = footprintMB()
        lock.lock(); stop = true; peak = max(peak, end); lock.unlock()
        lastPeakMB = peak - start
        lastRetainedMB = end - start
        return (r, ms)
    }

    /// The fetch the controller does (fetchImagesByCreationDate): hidden assets excluded, newest first,
    /// no media-type predicate. `sorted` and `mediaPredicate` exist only to time the variants.
    private func fetch(_ collection: PHAssetCollection?, sorted: Bool = true, mediaPredicate: Bool = false) -> PHFetchResult<PHAsset> {
        let o = PHFetchOptions()
        o.includeHiddenAssets = false
        if sorted { o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)] }
        if mediaPredicate {
            o.predicate = NSPredicate(format: "mediaType == %d || mediaType == %d",
                                      PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        }
        if let collection { return PHAsset.fetchAssets(in: collection, options: o) }
        return PHAsset.fetchAssets(with: o)
    }

    /// Count of assets created in [from, to), without creating any PHAsset.
    private func count(_ collection: PHAssetCollection?, from: Date, to: Date) -> Int {
        let o = PHFetchOptions()
        o.includeHiddenAssets = false
        o.predicate = NSPredicate(format: "creationDate >= %@ && creationDate < %@", from as NSDate, to as NSDate)
        if let collection { return PHAsset.fetchAssets(in: collection, options: o).count }
        return PHAsset.fetchAssets(with: o).count
    }

    /// Fresh-process memory test: windowed passes first (small baseline), then plain passes, with the allocator asked
    /// to give free pages back in between. Kill and relaunch the app before tapping the button.
    func runMemoryTest(collection: PHAssetCollection?, title: String) {
        guard !running else { return }
        DispatchQueue.main.async { self.running = true; self.log = "" }
        DispatchQueue.global(qos: .userInitiated).async {
            self.memoryTest(collection: collection, title: title)
            DispatchQueue.main.async { self.running = false }
        }
    }

    private func windowedDatePass(_ collection: PHAssetCollection?, component: Calendar.Component, newest: Date, oldest: Date) -> Int {
        let cal = Calendar.current
        var cur = cal.dateInterval(of: component, for: newest)
        var total = 0, windows = 0
        while let c = cur, c.end > oldest {
            windows += 1
            autoreleasepool {
                let o = PHFetchOptions()
                o.includeHiddenAssets = false
                o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                o.predicate = NSPredicate(format: "creationDate >= %@ && creationDate < %@", c.start as NSDate, c.end as NSDate)
                let r = collection.map { PHAsset.fetchAssets(in: $0, options: o) } ?? PHAsset.fetchAssets(with: o)
                total += r.count
                var i = 0
                while i < r.count {
                    autoreleasepool { for j in i..<min(i + 200, r.count) { _ = r.object(at: j).creationDate } }
                    i += 200
                }
            }
            cur = cal.dateInterval(of: component, for: c.start.addingTimeInterval(-1))
            if windows > 5_000 { break }
        }
        return total
    }

    private func plainPass(_ collection: PHAssetCollection?) -> Int {
        let r = fetch(collection)
        let n = r.count
        var i = 0
        while i < n {
            autoreleasepool { for j in i..<min(i + 200, n) { _ = r.object(at: j).creationDate } }
            i += 200
        }
        return n
    }

    private func relief() -> String {
        let before = footprintMB()
        _ = malloc_zone_pressure_relief(nil, 0)
        return String(format: "malloc_zone_pressure_relief: footprint %.0f -> %.0f MB", before, footprintMB())
    }

    private func memoryTest(collection: PHAssetCollection?, title: String) {
        let device = UIDevice.current
        say("== MEMORY TEST \(title) | \(device.model) iOS \(device.systemVersion) | thermal: \(ProcessInfo.processInfo.thermalState.rawValue)")
        say(String(format: "M0. footprint at start: %.0f MB (must be small: relaunch the app before this test)", footprintMB()))
        let first = fetch(collection)
        let n = first.count
        guard n > 0, let newest = first.object(at: 0).creationDate, let oldest = first.object(at: n - 1).creationDate else { return }
        say("M0. \(n) assets")

        if let src = PHWindowedSource(collection: collection) {
            var plan = WindowPlan()
            let planMs = time { plan = planWindows(src, maxWindow: probeMaxWindow) }.1
            say(String(format: "M0b. window plan: %d windows, %d count queries, %.0f ms (%@)", plan.leaves.count, plan.countQueries, planMs, memo as NSString))
            for t in [2, 1] {
                var r: (day: [IndexSet], week: [IndexSet], month: [IndexSet]) = ([], [], [])
                let wms = time { r = windowedPass(src, plan: plan, threads: t) }.1
                say(String(format: "M0c. windowed pass, %d thread(s): %.0f ms, sections day %d, week %d, month %d (%@)", t, wms, r.day.count, r.week.count, r.month.count, memo as NSString))
            }
        }

        var total = 0
        var ms = time { total = windowedDatePass(collection, component: .year, newest: newest, oldest: oldest) }.1
        say(String(format: "M1. windowed pass per year: %d assets (expected %d), %.0f ms (%@)", total, n, ms, memo as NSString))
        say("M1b. " + relief())

        ms = time { total = windowedDatePass(collection, component: .month, newest: newest, oldest: oldest) }.1
        say(String(format: "M2. windowed pass per month: %d assets (expected %d), %.0f ms (%@)", total, n, ms, memo as NSString))
        say("M2b. " + relief())

        for k in 1...3 {
            ms = time { total = plainPass(collection) }.1
            say(String(format: "M3.%d plain pass on a new result: %d assets, %.0f ms (%@)", k, total, ms, memo as NSString))
            say("M3.\(k)b " + relief())
        }

        ms = time { total = windowedDatePass(collection, component: .year, newest: newest, oldest: oldest) }.1
        say(String(format: "M4. windowed pass per year again: %d assets, %.0f ms (%@)", total, ms, memo as NSString))
        say(String(format: "M5. footprint at end: %.0f MB", footprintMB()))
    }

    func run(collection: PHAssetCollection?, title: String) {
        guard !running else { return }
        DispatchQueue.main.async { self.running = true; self.log = "" }
        DispatchQueue.global(qos: .userInitiated).async {
            self.measure(collection: collection, title: title)
            DispatchQueue.main.async { self.running = false }
        }
    }

    private func measure(collection: PHAssetCollection?, title: String) {
        let device = UIDevice.current
        say("== \(title) | \(device.model) iOS \(device.systemVersion) | low power: \(ProcessInfo.processInfo.isLowPowerModeEnabled) | thermal: \(ProcessInfo.processInfo.thermalState.rawValue)")
        #if DEBUG
        say("!! DEBUG build: numbers are not representative, use Release")
        #endif

        // a. Fetch
        var (result, ms) = time { fetch(collection) }
        let n = result.count
        say(String(format: "a. fetch: %d assets in %.1f ms", n, ms))
        guard n > 0 else { return }
        // a2. The same fetch, varied: unsorted, and with the media-type predicate
        let (unsorted, msUnsorted) = time { fetch(collection, sorted: false) }
        let (withPredicate, msPredicate) = time { fetch(collection, mediaPredicate: true) }
        say(String(format: "a2. variants: unsorted %.1f ms (%d), sorted+media predicate %.1f ms (%d)", msUnsorted, unsorted.count, msPredicate, withPredicate.count))
        let sample = min(n, 2_000)

        // b. Random reads of creationDate on a fresh result (cold)
        result = fetch(collection)
        var rng = SystemRandomNumberGenerator()
        let randomIdx = (0..<sample).map { _ in Int.random(in: 0..<n, using: &rng) }
        var sink = 0.0
        ms = time { for i in randomIdx { sink += result.object(at: i).creationDate?.timeIntervalSinceReferenceDate ?? 0 } }.1
        say(String(format: "b. %d random creationDate reads (cold): %.1f ms = %.0f µs/read", sample, ms, ms * 1000 / Double(sample)))

        // c. Full sequential pass reading creationDate, fresh result
        result = fetch(collection)
        var mem0 = residentMB()
        ms = time { for i in 0..<n { sink += result.object(at: i).creationDate?.timeIntervalSinceReferenceDate ?? 0 } }.1
        say(String(format: "c. all %d creationDate reads, sequential: %.0f ms = %.1f µs/read (%@)", n, ms, ms * 1000 / Double(n), memo as NSString))

        // d. Full sequential pass materialising localIdentifier into [String], fresh result
        result = fetch(collection)
        mem0 = residentMB()
        var ids = [String](); ids.reserveCapacity(n)
        ms = time { for i in 0..<n { ids.append(result.object(at: i).localIdentifier) } }.1
        say(String(format: "d. all %d localIdentifiers into [String]: %.0f ms = %.1f µs/asset (RSS %+.1f MB, ids retained)", n, ms, ms * 1000 / Double(n), residentMB() - mem0))
        sink += Double(ids.count)

        // e. Same with enumerateObjects, which is how PhotoKit prefers to be walked
        result = fetch(collection)
        var viaEnum = 0
        ms = time { result.enumerateObjects { a, _, _ in viaEnum += a.localIdentifier.utf8.count } }.1
        say(String(format: "e. enumerateObjects over %d assets reading localIdentifier: %.0f ms", n, ms))

        // f. Layout by galloping, real reads
        result = fetch(collection)
        let source = PHSource(result)
        for g in [Grouping.month, .week, .day] {
            result = fetch(collection)
            let src = PHSource(result)
            let rss0 = residentMB()
            let (layout, lms) = time { build(src, grouping: g) }
            say(String(format: "f. layout %-5@: %6d sections, %7d reads, %8.1f ms, RSS %+.1f MB (reading every date: %d reads)",
                       "\(g)" as NSString, layout.count, src.reads, lms, residentMB() - rss0, n))
        }
        _ = source

        // f2. Warm second pass over the same result: are the objects cached?
        result = fetch(collection)
        for pass in 1...2 {
            ms = time { for i in 0..<n { sink += result.object(at: i).creationDate?.timeIntervalSinceReferenceDate ?? 0 } }.1
            say(String(format: "f2. sequential date pass %d on the same result: %.0f ms = %.1f µs/read", pass, ms, ms * 1000 / Double(n)))
        }

        // p. The app's current single pass (all three groupings at once), as it is and with a pool per block
        for pooled in [false, true] {
            result = fetch(collection)
            let rss0 = residentMB()
            var out: (day: [IndexSet], week: [IndexSet], month: [IndexSet]) = ([], [], [])
            ms = time { out = appSinglePass(result, pooled: pooled) }.1
            say(String(format: "p. app single pass%@: %.0f ms = %.1f µs/asset for day+week+month together; sections day %d, week %d, month %d; %@",
                       pooled ? " + pool per 1000" : " (as is)" as NSString, ms, ms * 1000 / Double(n),
                       out.day.count, out.week.count, out.month.count, memo as NSString)); _ = rss0
        }
        // p4. The same single pass split in two parallel chunks, joined, and checked against the serial result
        do {
            result = fetch(collection)
            let serial = appSinglePass(result, pooled: true)
            for threads in [2] {
                result = fetch(collection)
                var par: (day: [IndexSet], week: [IndexSet], month: [IndexSet]) = ([], [], [])
                ms = time { par = appParallelPass(result, threads: threads) }.1
                let same = par.day == serial.day && par.week == serial.week && par.month == serial.month
                say(String(format: "p4. app single pass on %d parallel chunks: %.0f ms = %.1f µs/asset; sections day %d, week %d, month %d; identical to serial: %@; %@",
                           threads, ms, ms * 1000 / Double(n), par.day.count, par.week.count, par.month.count, same ? "yes" : "NO" as NSString, memo as NSString))
                if threads == 2, let src = PHWindowedSource(collection: collection) {
                    var plan = WindowPlan()
                    let planMs = time { plan = planWindows(src, maxWindow: probeMaxWindow) }.1
                    let largest = plan.leaves.map(\.count).max() ?? 0
                    say(String(format: "x0. window plan: %d windows, largest %d assets, %d count queries, %.0f ms, covers %d of %d assets",
                               plan.leaves.count, largest, plan.countQueries, planMs, plan.total, n))
                    for t in [1, 2] {
                        var win: (day: [IndexSet], week: [IndexSet], month: [IndexSet]) = ([], [], [])
                        let wms = time { win = windowedPass(src, plan: plan, threads: t) }.1
                        let same = win.day == serial.day && win.week == serial.week && win.month == serial.month
                        say(String(format: "x. windowed pass on %d thread(s): %.0f ms = %.1f µs/asset (+ plan %.0f ms); sections day %d, week %d, month %d; identical to serial: %@; %@",
                                   t, wms, wms * 1000 / Double(n), planMs, win.day.count, win.week.count, win.month.count, same ? "yes" : "NO" as NSString, memo as NSString))
                    }
                }
            }
        }

        // p3. The calendar work alone, on dates already read: how much of the pass is CPU rather than PhotoKit?
        do {
            result = fetch(collection)
            var dates = [Date](); dates.reserveCapacity(n)
            var i = 0
            while i < n { autoreleasepool { for j in i..<min(i + 200, n) { dates.append(result.object(at: j).creationDate ?? Date()) } }; i += 200 }
            let cal = Calendar.current
            let byDays: Set<Calendar.Component> = [.year, .month, .day]
            var changes = 0
            var last = cal.dateComponents(byDays, from: dates[0])
            ms = time { for d in dates { let c = cal.dateComponents(byDays, from: d); if c != last { changes += 1; last = c } } }.1
            say(String(format: "p3. calendar.dateComponents alone on %d dates already in memory: %.0f ms = %.1f µs/asset (%d day changes)", n, ms, ms * 1000 / Double(n), changes))
        }

        // k. Batch size: time consecutive reads from random starts; slow reads mark batch loads
        result = fetch(collection)
        var slowGaps = [Int](), firstReads = [Double](), otherReads = [Double]()
        for _ in 0..<min(20, max(1, n / 400)) {
            let startIdx = Int.random(in: 0..<max(1, n - 400), using: &rng)
            var lastSlow = -1
            for k in 0..<min(400, n - startIdx) {
                let t = CFAbsoluteTimeGetCurrent()
                sink += result.object(at: startIdx + k).creationDate?.timeIntervalSinceReferenceDate ?? 0
                let us = (CFAbsoluteTimeGetCurrent() - t) * 1_000_000
                if k == 0 { firstReads.append(us) } else { otherReads.append(us) }
                if us > 1_000 { if lastSlow >= 0 { slowGaps.append(k - lastSlow) }; lastSlow = k }
            }
        }
        slowGaps.sort()
        say(String(format: "k. first read at a random spot: median %.0f µs; following reads: median %.1f µs, p99 %.0f µs; gaps between slow reads (>1 ms): median %d, count %d",
                   firstReads.sorted()[firstReads.count / 2], otherReads.sorted()[otherReads.count / 2],
                   otherReads.sorted()[Int(Double(otherReads.count) * 0.99)], slowGaps.isEmpty ? 0 : slowGaps[slowGaps.count / 2], slowGaps.count))

        // h. Count-only queries per calendar period: no asset object is created
        result = fetch(collection)
        let newest = result.object(at: 0).creationDate ?? Date(), oldest = result.object(at: n - 1).creationDate ?? Date()
        for g in [Grouping.month, .week, .day] {
            var periods = [(Date, Date)]()
            let cal = Calendar.current
            var cur = cal.dateInterval(of: g.component, for: newest)
            while let c = cur, c.end > oldest {
                periods.append((c.start, c.end))
                cur = cal.dateInterval(of: g.component, for: c.start.addingTimeInterval(-1))
                if periods.count > 100_000 { break }
            }
            let sampleCount = min(periods.count, 150)
            let stride = max(1, periods.count / sampleCount)
            let picked = Swift.stride(from: 0, to: periods.count, by: stride).map { periods[$0] }
            let rss0 = residentMB()
            var total = 0, nonEmpty = 0
            let qms = time { for (from, to) in picked { let c = self.count(collection, from: from, to: to); total += c; if c > 0 { nonEmpty += 1 } } }.1
            let perQuery = qms / Double(picked.count)
            say(String(format: "h. count queries %-5@: %d calendar periods (%d sampled, %d non-empty): %.2f ms/query => ~%.0f ms for all periods, RSS %+.1f MB",
                       "\(g)" as NSString, periods.count, picked.count, nonEmpty, perQuery, perQuery * Double(periods.count), residentMB() - rss0))
            sink += Double(total)
        }

        // h2. Jump over empty periods: the next asset older than a date, sorted, limit 1
        result = fetch(collection)
        var jumpDates = [Date]()
        for _ in 0..<min(100, n) { if let d = result.object(at: Int.random(in: 0..<n, using: &rng)).creationDate { jumpDates.append(d) } }
        ms = time {
            for d in jumpDates {
                let o = PHFetchOptions()
                o.includeHiddenAssets = false
                o.fetchLimit = 1
                o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                o.predicate = NSPredicate(format: "creationDate < %@", d as NSDate)
                let r = collection.map { PHAsset.fetchAssets(in: $0, options: o) } ?? PHAsset.fetchAssets(with: o)
                sink += Double(r.count)
            }
        }.1
        say(String(format: "h2. 'next older asset' query (limit 1): %d queries, %.2f ms each. Library spans %@ to %@",
                   jumpDates.count, ms / Double(max(1, jumpDates.count)),
                   DateFormatter.localizedString(from: oldest, dateStyle: .medium, timeStyle: .none),
                   DateFormatter.localizedString(from: newest, dateStyle: .medium, timeStyle: .none)))

        // h3. Per-section lazy fetch: one month of assets, sorted, by date predicate. Is it proportional to the month?
        do {
            let cal = Calendar.current
            let months = (0..<12).compactMap { _ -> DateInterval? in
                let d = result.object(at: Int.random(in: 0..<n, using: &rng)).creationDate ?? newest
                return cal.dateInterval(of: .month, for: d)
            }
            var sizes = [Int](), fetchMs = [Double](), readMs = [Double]()
            for m in months {
                let o = PHFetchOptions()
                o.includeHiddenAssets = false
                o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                o.predicate = NSPredicate(format: "creationDate >= %@ && creationDate < %@", m.start as NSDate, m.end as NSDate)
                var r: PHFetchResult<PHAsset>! = nil
                let f = time { r = collection.map { PHAsset.fetchAssets(in: $0, options: o) } ?? PHAsset.fetchAssets(with: o) }.1
                let k = min(r.count, 200)
                let rd = time { for i in 0..<k { sink += r.object(at: i).creationDate?.timeIntervalSinceReferenceDate ?? 0 } }.1
                sizes.append(r.count); fetchMs.append(f); readMs.append(k > 0 ? rd * 1000 / Double(k) : 0)
            }
            say("h3. month fetches (size: fetch ms, µs/read of first 200): " + zip(sizes, zip(fetchMs, readMs)).sorted { $0.0 > $1.0 }
                .map { String(format: "%d: %.1f ms, %.0f µs", $0.0, $0.1.0, $0.1.1) }.joined(separator: " | "))
        }

        // m. Memory done properly: a pool drained every 200 reads (one batch), result retained
        do {
            result = fetch(collection)
            let rssBefore = footprintMB()
            ms = time {
                var i = 0
                while i < n {
                    autoreleasepool { for j in i..<min(i + 200, n) { sink += result.object(at: j).creationDate?.timeIntervalSinceReferenceDate ?? 0 } }
                    i += 200
                }
            }.1
            say(String(format: "m. sequential date pass, pool per 200: %.0f ms = %.1f µs/read (%@; footprint before %.0f MB)",
                       ms, ms * 1000 / Double(n), memo as NSString, rssBefore))
        }

        // r. Does releasing the PHFetchResult free what a full pass loaded? Pass on a throwaway result, then
        //    again on one kept alive: "kept" is measured after the block, i.e. after the throwaway result is gone.
        do {
            let before = footprintMB()
            ms = time {
                let throwaway = fetch(collection)
                var acc = 0.0
                var i = 0
                while i < n {
                    autoreleasepool { for j in i..<min(i + 200, n) { acc += throwaway.object(at: j).creationDate?.timeIntervalSinceReferenceDate ?? 0 } }
                    i += 200
                }
                sink += acc
            }.1
            say(String(format: "r1. pass on a throwaway result: %.0f ms (%@; footprint before %.0f MB)", ms, memo as NSString, before))
            let kept = fetch(collection)
            for pass in 1...2 {
                ms = time {
                    var acc = 0.0
                    var i = 0
                    while i < n {
                        autoreleasepool { for j in i..<min(i + 200, n) { acc += kept.object(at: j).creationDate?.timeIntervalSinceReferenceDate ?? 0 } }
                        i += 200
                    }
                    sink += acc
                }.1
                say(String(format: "r2. pass %d on a result kept alive: %.0f ms = %.1f µs/read (%@)", pass, ms, ms * 1000 / Double(n), memo as NSString))
            }
        }

        // w. Windowed pass: one fetch result per calendar year (then per month), released after use. Is the working set bounded?
        do {
            let cal = Calendar.current
            for (label, component) in [("year", Calendar.Component.year), ("month", .month)] {
                var windows = [DateInterval]()
                var cur = cal.dateInterval(of: component, for: newest)
                while let c = cur, c.end > oldest {
                    windows.append(c)
                    cur = cal.dateInterval(of: component, for: c.start.addingTimeInterval(-1))
                    if windows.count > 5_000 { break }
                }
                var total = 0, nonEmpty = 0
                let before = footprintMB()
                ms = time {
                    var acc = 0.0
                    for w in windows {
                        autoreleasepool {
                            let o = PHFetchOptions()
                            o.includeHiddenAssets = false
                            o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                            o.predicate = NSPredicate(format: "creationDate >= %@ && creationDate < %@", w.start as NSDate, w.end as NSDate)
                            let r = collection.map { PHAsset.fetchAssets(in: $0, options: o) } ?? PHAsset.fetchAssets(with: o)
                            if r.count > 0 { nonEmpty += 1 }
                            total += r.count
                            var i = 0
                            while i < r.count {
                                autoreleasepool { for j in i..<min(i + 200, r.count) { acc += r.object(at: j).creationDate?.timeIntervalSinceReferenceDate ?? 0 } }
                                i += 200
                            }
                        }
                    }
                    sink += acc
                }.1
                say(String(format: "w. windowed date pass, one fetch per %@: %d windows (%d non-empty), %d assets, %.0f ms = %.1f µs/asset (%@; footprint before %.0f MB)",
                           label as NSString, windows.count, nonEmpty, total, ms, ms * 1000 / Double(max(1, total)), memo as NSString, before))
            }
        }

        // n. Parallel batch loads: does the full pass scale with threads?
        for threads in [2, 4, 8] {
            result = fetch(collection)
            let local = result
            let chunk = (n + threads - 1) / threads
            var partial = [Double](repeating: 0, count: threads)
            ms = time {
                partial.withUnsafeMutableBufferPointer { buf in
                    let base = buf.baseAddress!
                    DispatchQueue.concurrentPerform(iterations: threads) { t in
                        var acc = 0.0
                        var i = t * chunk
                        let end = min(n, (t + 1) * chunk)
                        while i < end {
                            autoreleasepool { for j in i..<min(i + 200, end) { acc += local.object(at: j).creationDate?.timeIntervalSinceReferenceDate ?? 0 } }
                            i += 200
                        }
                        base[t] = acc
                    }
                }
            }.1
            sink += partial.reduce(0, +)
            say(String(format: "n. parallel date pass, %d threads: %.0f ms (%.1f µs/read effective; %@)", threads, ms, ms * 1000 / Double(n), memo as NSString))
        }

        // h4. Parallel count queries, and count-based boundaries checked against the real ones
        do {
            let cal = Calendar.current
            var periods = [(Date, Date)]()
            var cur = cal.dateInterval(of: .month, for: newest)
            while let c = cur, c.end > oldest {
                periods.append((c.start, c.end))
                cur = cal.dateInterval(of: .month, for: c.start.addingTimeInterval(-1))
                if periods.count > 5_000 { break }
            }
            let picked = Array(periods.prefix(160))
            for threads in [1, 4, 8] {
                var totals = [Int](repeating: 0, count: picked.count)
                ms = time {
                    totals.withUnsafeMutableBufferPointer { buf in
                        let base = buf.baseAddress!
                        DispatchQueue.concurrentPerform(iterations: threads) { t in
                            var i = t
                            while i < picked.count { base[i] = self.count(collection, from: picked[i].0, to: picked[i].1); i += threads }
                        }
                    }
                }.1
                sink += Double(totals.reduce(0, +))
                say(String(format: "h4. %d count queries on %d threads: %.0f ms total = %.2f ms/query effective", picked.count, threads, ms, ms / Double(picked.count)))
            }

            // Boundary check: first asset older than month start has index = count(creationDate >= start)
            result = fetch(collection)
            let src = PHSource(result)
            let layout = autoreleasepool { build(src, grouping: .month) }
            var mismatches = 0, checked = 0
            for r in layout.prefix(40) {
                guard let d = result.object(at: r.lowerBound).creationDate,
                      let start = cal.dateInterval(of: .month, for: d)?.start else { continue }
                let viaCount = self.count(collection, from: start, to: newest.addingTimeInterval(86_400 * 366))
                checked += 1
                if viaCount != r.upperBound { mismatches += 1 }
            }
            say("h4b. count-based month boundaries vs real ones: \(checked) checked, \(mismatches) mismatches")
        }

        // g. index(of:) cost, the call the controller uses to map uploads to indices
        result = fetch(collection)
        let probes = (0..<min(20, n)).map { _ in Int.random(in: 0..<n, using: &rng) }
        let assets = probes.map { result.object(at: $0) }
        ms = time { for a in assets { sink += Double(result.index(of: a)) } }.1
        say(String(format: "g. index(of:) on %d assets: %.1f ms = %.1f ms each", assets.count, ms, ms / Double(assets.count)))

        say(String(format: "done (sink %.0f). RSS now %.0f MB", sink + Double(viaEnum), residentMB()))
    }
}

// MARK: - Galloping layout (same algorithm as Sources/LayoutSpike/Layout.swift)
enum Grouping { case month, week, day
    var component: Calendar.Component { switch self { case .month: return .month; case .week: return .weekOfYear; case .day: return .day } }
}

final class PHSource {
    let result: PHFetchResult<PHAsset>
    var reads = 0
    var count: Int { result.count }
    init(_ r: PHFetchResult<PHAsset>) { result = r }
    func date(at i: Int) -> Date { reads += 1; return result.object(at: i).creationDate ?? .distantPast }
}

func build(_ s: PHSource, grouping: Grouping) -> [Range<Int>] {
    let n = s.count, cal = Calendar.current
    var ranges = [Range<Int>](); var start = 0
    while start < n {
        let first = s.date(at: start)
        let lower = cal.dateInterval(of: grouping.component, for: first)?.start ?? first
        var lo = start, step = 1, hi = n
        while true {
            let probe = start + step
            if probe >= n { hi = n; break }
            if s.date(at: probe) >= lower { lo = probe; step <<= 1 } else { hi = probe; break }
        }
        while hi - lo > 1 {
            let mid = lo + (hi - lo) / 2
            if s.date(at: mid) >= lower { lo = mid } else { hi = mid }
        }
        ranges.append(start..<hi); start = hi
    }
    return ranges
}

// MARK: - The app's current method (LocalImagesViewController+Data.swift, sortByMonthWeekDay)
// BEGIN SHARED WITH Probe/PhotoKitProbe.swift (keep identical; no PhotoKit here)

/// Sections of one chunk of the library plus the calendar keys at both ends, so that chunks can be joined.
struct GroupingChunk {
    var day = [IndexSet](), week = [IndexSet](), month = [IndexSet]()
    var firstDay = DateComponents(), lastDay = DateComponents()
    var firstWeek = DateComponents(), lastWeek = DateComponents()
    var firstMonth = DateComponents(), lastMonth = DateComponents()
}

/// The controller's single pass (sortByMonthWeekDay): reads each creation date once and computes day, week and
/// month sections together, in blocks of 1,000, over `range`. `pooled` adds an autoreleasepool per block.
func appPass(dateAt: (Int) -> Date?, range: Range<Int>, pooled: Bool) -> GroupingChunk {
    let calendar = Calendar.current
    let byDays: Set<Calendar.Component> = [.year, .month, .day]
    let byWeeks: Set<Calendar.Component> = [.year, .weekOfYear]
    let byMonths: Set<Calendar.Component> = [.year, .month]
    var out = GroupingChunk()
    guard !range.isEmpty else { return out }
    let first = dateAt(range.lowerBound) ?? Date()
    var dayComponents = calendar.dateComponents(byDays, from: first)
    var weekComponents = calendar.dateComponents(byWeeks, from: first)
    var monthComponents = calendar.dateComponents(byMonths, from: first)
    out.firstDay = dayComponents; out.firstWeek = weekComponents; out.firstMonth = monthComponents
    var firstDay = range.lowerBound, firstWeek = range.lowerBound, firstMonth = range.lowerBound
    let step = 1_000
    var blockStart = range.lowerBound
    while blockStart < range.upperBound {
        let blockEnd = min(blockStart + step, range.upperBound)
        func body() {
            for index in blockStart..<blockEnd {
                let creationDate = dateAt(index) ?? Date()
                let newDay = calendar.dateComponents(byDays, from: creationDate)
                if newDay == dayComponents { continue }
                out.day.append(IndexSet(integersIn: firstDay..<index))
                firstDay = index
                dayComponents = newDay
                let newWeek = calendar.dateComponents(byWeeks, from: creationDate)
                if newWeek != weekComponents {
                    out.week.append(IndexSet(integersIn: firstWeek..<index))
                    firstWeek = index
                    weekComponents = newWeek
                }
                let newMonth = calendar.dateComponents(byMonths, from: creationDate)
                if newMonth != monthComponents {
                    out.month.append(IndexSet(integersIn: firstMonth..<index))
                    firstMonth = index
                    monthComponents = newMonth
                }
            }
        }
        if pooled { autoreleasepool { body() } } else { body() }
        blockStart = blockEnd
    }
    out.day.append(IndexSet(integersIn: firstDay..<range.upperBound))
    out.week.append(IndexSet(integersIn: firstWeek..<range.upperBound))
    out.month.append(IndexSet(integersIn: firstMonth..<range.upperBound))
    out.lastDay = dayComponents; out.lastWeek = weekComponents; out.lastMonth = monthComponents
    return out
}

/// Joins two consecutive chunks: a section which straddles the cut is the union of both halves.
func join(_ a: GroupingChunk, _ b: GroupingChunk) -> GroupingChunk {
    func merge(_ x: [IndexSet], _ y: [IndexSet], same: Bool) -> [IndexSet] {
        guard same, let lastX = x.last, let firstY = y.first else { return x + y }
        return x.dropLast() + [lastX.union(firstY)] + y.dropFirst()
    }
    var out = GroupingChunk()
    out.day = merge(a.day, b.day, same: a.lastDay == b.firstDay)
    out.week = merge(a.week, b.week, same: a.lastWeek == b.firstWeek)
    out.month = merge(a.month, b.month, same: a.lastMonth == b.firstMonth)
    // The joined chunk starts where `a` starts and ends where `b` ends, so it can be joined again.
    out.firstDay = a.firstDay; out.firstWeek = a.firstWeek; out.firstMonth = a.firstMonth
    out.lastDay = b.lastDay; out.lastWeek = b.lastWeek; out.lastMonth = b.lastMonth
    return out
}

/// The same pass split in consecutive chunks on a concurrent queue. `align` is the cut granularity
/// (PhotoKit loads 200 assets per batch); `minChunk` keeps small libraries on one thread.
func appParallelPass(dateAt: (Int) -> Date?, count n: Int, threads: Int, align: Int = 200, minChunk: Int = 400)
    -> (day: [IndexSet], week: [IndexSet], month: [IndexSet]) {
    guard threads > 1, n >= threads * minChunk else {
        let c = appPass(dateAt: dateAt, range: 0..<n, pooled: true)
        return (c.day, c.week, c.month)
    }
    let size = max(align, ((n / threads) / align) * align)
    var chunks = [GroupingChunk](repeating: GroupingChunk(), count: threads)
    chunks.withUnsafeMutableBufferPointer { buf in
        let base = buf.baseAddress!
        withoutActuallyEscaping(dateAt) { escapable in
            DispatchQueue.concurrentPerform(iterations: threads) { t in
                let lower = min(n, t * size)
                let upper = (t == threads - 1) ? n : min(n, (t + 1) * size)
                base[t] = appPass(dateAt: escapable, range: lower..<upper, pooled: true)
            }
        }
    }
    let joined = chunks.dropFirst().reduce(chunks[0]) { join($0, $1) }
    return (joined.day, joined.week, joined.month)
}

// END SHARED

// BEGIN SHARED WITH Probe/PhotoKitProbe.swift (keep identical; no PhotoKit here; needs the AppPass shared block)

/// A window of the library, newest first: it is created for one date interval and released after use, so that
/// PhotoKit's per-result cache (about 2.3 KB per asset) never covers more than one window per thread.
protocol DateWindow: AnyObject {
    var count: Int { get }
    func date(at index: Int) -> Date?
}

/// What the windowed pass needs from the library.
protocol WindowedSource {
    /// Number of assets of the whole collection.
    var totalCount: Int { get }
    var newestDate: Date { get }
    var oldestDate: Date { get }
    /// Count query: assets created in [from, to). Creates no asset.
    func count(from: Date, to: Date) -> Int
    /// The same assets, newest first. `.distantPast` … `.distantFuture` means the whole collection.
    func window(from: Date, to: Date) -> DateWindow
}

struct WindowLeaf {
    let interval: DateInterval
    let count: Int
    let offset: Int           // position of the window's first asset in the global (newest first) order
    var end: Int { offset + count }
}

struct WindowPlan {
    var leaves = [WindowLeaf]()
    var total: Int { leaves.last?.end ?? 0 }
    var countQueries = 0
}

/// Plans the windows: count per calendar year (count queries), a year holding more than `maxWindow` assets is cut
/// into months, a month into days. A library of at most `maxWindow` assets is one window and costs no query.
func planWindows(_ source: WindowedSource, maxWindow: Int, calendar: Calendar = .current) -> WindowPlan {
    var plan = WindowPlan()
    let n = source.totalCount
    guard n > 0 else { return plan }
    if n <= maxWindow {
        plan.leaves = [WindowLeaf(interval: DateInterval(start: .distantPast, end: .distantFuture), count: n, offset: 0)]
        return plan
    }
    let levels: [Calendar.Component] = [.year, .month, .day]
    var offset = 0
    func visit(_ interval: DateInterval, level: Int) {
        plan.countQueries += 1
        let c = source.count(from: interval.start, to: interval.end)
        if c == 0 { return }
        if c <= maxWindow || level == levels.count - 1 {
            plan.leaves.append(WindowLeaf(interval: interval, count: c, offset: offset))
            offset += c
            return
        }
        var children = [DateInterval]()
        var cur = calendar.dateInterval(of: levels[level + 1], for: interval.start)
        while let child = cur, child.start < interval.end {
            children.append(child)
            cur = calendar.dateInterval(of: levels[level + 1], for: child.end)
        }
        for child in children.reversed() { visit(child, level: level + 1) }
    }
    var year = calendar.dateInterval(of: .year, for: source.newestDate)
    let oldest = source.oldestDate
    while let y = year, y.end > oldest {
        visit(y, level: 0)
        year = calendar.dateInterval(of: .year, for: y.start.addingTimeInterval(-1))
    }
    return plan
}

/// Maps a global position to a date, holding one window at a time; positions are read in increasing order.
final class WindowCursor {
    private let source: WindowedSource
    private let leaves: [WindowLeaf]
    private var leafIndex = -1
    private var window: DateWindow?

    init(source: WindowedSource, leaves: [WindowLeaf]) { self.source = source; self.leaves = leaves }

    func date(at position: Int) -> Date? {
        if leafIndex < 0 || position < leaves[leafIndex].offset || position >= leaves[leafIndex].end {
            var lo = 0, hi = leaves.count - 1
            while lo < hi {
                let mid = (lo + hi) / 2
                if leaves[mid].end <= position { lo = mid + 1 } else { hi = mid }
            }
            window = nil                                  // release the previous window first
            leafIndex = lo
            window = source.window(from: leaves[lo].interval.start, to: leaves[lo].interval.end)
        }
        let local = position - leaves[leafIndex].offset
        guard let w = window, local < w.count else { return nil }
        return w.date(at: local)
    }
}

/// The controller's single pass over the windows, on `threads` threads: each thread takes consecutive windows
/// holding about the same number of assets, and the straddling sections are joined.
func windowedPass(_ source: WindowedSource, plan: WindowPlan, threads: Int)
    -> (day: [IndexSet], week: [IndexSet], month: [IndexSet]) {
    let leaves = plan.leaves
    guard !leaves.isEmpty else { return ([], [], []) }
    let threads = max(1, min(threads, leaves.count))
    // Cut at the leaf boundary closest to total * t / threads.
    var cuts = [0]
    for t in 1..<max(threads, 1) {
        let target = plan.total * t / threads
        var lo = cuts.last!, hi = leaves.count - 1
        while lo < hi {                                    // the leaf holding `target`
            let mid = (lo + hi) / 2
            if leaves[mid].end <= target { lo = mid + 1 } else { hi = mid }
        }
        let cut = (target - leaves[lo].offset <= leaves[lo].end - target) ? lo : lo + 1
        if cut > cuts.last! && cut < leaves.count { cuts.append(cut) }
    }
    cuts.append(leaves.count)
    let chunkCount = cuts.count - 1
    var chunks = [GroupingChunk](repeating: GroupingChunk(), count: chunkCount)
    chunks.withUnsafeMutableBufferPointer { buf in
        let base = buf.baseAddress!
        DispatchQueue.concurrentPerform(iterations: chunkCount) { c in
            let mine = Array(leaves[cuts[c]..<cuts[c + 1]])
            let cursor = WindowCursor(source: source, leaves: mine)
            base[c] = appPass(dateAt: { cursor.date(at: $0) }, range: mine.first!.offset..<mine.last!.end, pooled: true)
        }
    }
    let joined = chunks.dropFirst().reduce(chunks[0]) { join($0, $1) }
    return (joined.day, joined.week, joined.month)
}

// END SHARED

// MARK: - Windowed pass: PhotoKit adapter
final class PHWindow: DateWindow {
    let result: PHFetchResult<PHAsset>
    init(_ r: PHFetchResult<PHAsset>) { result = r }
    var count: Int { result.count }
    func date(at index: Int) -> Date? { result.object(at: index).creationDate }
}

final class PHWindowedSource: WindowedSource {
    let collection: PHAssetCollection?
    let totalCount: Int
    let newestDate: Date
    let oldestDate: Date

    static func fetch(_ collection: PHAssetCollection?, from: Date?, to: Date?, sorted: Bool) -> PHFetchResult<PHAsset> {
        let o = PHFetchOptions()
        o.includeHiddenAssets = false
        if sorted { o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)] }
        if let from = from, let to = to {
            o.predicate = NSPredicate(format: "creationDate >= %@ && creationDate < %@", from as NSDate, to as NSDate)
        }
        if let collection = collection { return PHAsset.fetchAssets(in: collection, options: o) }
        return PHAsset.fetchAssets(with: o)
    }

    init?(collection: PHAssetCollection?) {
        let all = PHWindowedSource.fetch(collection, from: nil, to: nil, sorted: true)
        guard all.count > 0, let newest = all.object(at: 0).creationDate,
              let oldest = all.object(at: all.count - 1).creationDate else { return nil }
        self.collection = collection
        totalCount = all.count
        newestDate = newest
        oldestDate = oldest
    }

    func count(from: Date, to: Date) -> Int {
        PHWindowedSource.fetch(collection, from: from, to: to, sorted: false).count
    }

    func window(from: Date, to: Date) -> DateWindow {
        let whole = from == .distantPast && to == .distantFuture
        return PHWindow(PHWindowedSource.fetch(collection, from: whole ? nil : from, to: whole ? nil : to, sorted: true))
    }
}


func appSinglePass(_ images: PHFetchResult<PHAsset>, pooled: Bool) -> (day: [IndexSet], week: [IndexSet], month: [IndexSet]) {
    let c = appPass(dateAt: { images[$0].creationDate }, range: 0..<images.count, pooled: pooled)
    return (c.day, c.week, c.month)
}

func appParallelPass(_ images: PHFetchResult<PHAsset>, threads: Int) -> (day: [IndexSet], week: [IndexSet], month: [IndexSet]) {
    appParallelPass(dateAt: { images[$0].creationDate }, count: images.count, threads: threads)
}

// MARK: - UI
struct ProbeView: View {
    @StateObject private var probe = Probe()
    @State private var selection = 0
    @State private var authorised = false

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                if authorised {
                    Picker("Collection", selection: $selection) {
                        ForEach(probe.collections.indices, id: \.self) { i in
                            let c = probe.collections[i]
                            Text(c.estimate >= 0 ? "\(c.title) (\(c.estimate))" : c.title).tag(i)
                        }
                    }
                    HStack {
                        Button("Run") {
                            guard probe.collections.indices.contains(selection) else { return }
                            let c = probe.collections[selection]
                            probe.run(collection: c.collection, title: c.title)
                        }.disabled(probe.running).buttonStyle(.borderedProminent)
                        Button("Memory test") {
                            guard probe.collections.indices.contains(selection) else { return }
                            let c = probe.collections[selection]
                            probe.runMemoryTest(collection: c.collection, title: c.title)
                        }.disabled(probe.running).buttonStyle(.bordered)
                        Button("Copy log") { UIPasteboard.general.string = probe.log }
                        if probe.running { ProgressView() }
                    }
                } else {
                    Text("Photo Library access is needed.")
                }
                ScrollView { Text(probe.log).font(.system(size: 11, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading) }
            }
            .padding()
            .navigationTitle("PhotoKit probe")
        }
        .onAppear {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    authorised = (status == .authorized || status == .limited)
                    if authorised {
                        probe.loadCollections()
                        if CommandLine.arguments.contains("--memorytest") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { probe.runMemoryTest(collection: nil, title: "All Photos") }
                        }
                        if CommandLine.arguments.contains("--autorun") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { probe.run(collection: nil, title: "All Photos") }
                        }
                    }
                }
            }
        }
    }
}
