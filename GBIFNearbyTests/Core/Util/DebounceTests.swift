import Testing
import Foundation
@testable import GBIFNearby

@Suite("AsyncDebouncer")
struct DebounceTests {
    @Test("fires only the last scheduled action after the delay")
    func collapseRapidCalls() async {
        let debouncer = AsyncDebouncer(delay: .milliseconds(100))
        actor Counter { var n = 0; func inc() { n += 1 } }
        let counter = Counter()
        await debouncer.schedule { await counter.inc() }
        await debouncer.schedule { await counter.inc() }
        await debouncer.schedule { await counter.inc() }
        try? await Task.sleep(for: .milliseconds(250))
        #expect(await counter.n == 1)
    }

    @Test("cancel prevents the pending action")
    func cancel() async {
        let debouncer = AsyncDebouncer(delay: .milliseconds(100))
        actor Flag { var fired = false; func set() { fired = true } }
        let flag = Flag()
        await debouncer.schedule { await flag.set() }
        await debouncer.cancel()
        try? await Task.sleep(for: .milliseconds(200))
        #expect(await flag.fired == false)
    }
}
