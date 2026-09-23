import Testing
@testable import ScopaRelay

/// The four letters, and the number they fold into so they can ride inside a Game Center
/// invitation. A code that comes back wrong seats a friend at a table nobody is at.
@Suite struct InviteGroupTests {
    @Test func everyCodeSurvivesTheRoundTrip() {
        // Every letter in every position, which is the whole of what a code can be.
        for (index, first) in Relay.alphabet.enumerated() {
            let rest = Relay.alphabet.dropFirst(index % Relay.alphabet.count).prefix(3)
            let code = String(first) + String(rest).padding(toLength: 3, withPad: "2", startingAt: 0)
            let group = Relay.inviteGroup(for: code)
            #expect(group != nil)
            #expect(Relay.code(inGroup: group!) == code)
        }
    }

    @Test func aTidiedCodeIsTheOneThatTravels() {
        #expect(Relay.inviteGroup(for: "le-k9") == Relay.inviteGroup(for: "LEK9"))
        #expect(Relay.inviteGroup(for: "LEK") == nil)
        #expect(Relay.inviteGroup(for: "LEK01") == nil)
    }

    /// A pool is a hash of its name and lands anywhere in the range; the reserved block is
    /// the one place it must not, or an ordinary match would be read as a table of ours.
    @Test func ordinaryMatchmakingGroupsAreNotCodes() {
        for group in [1, 0x0B55_E982, 0x1234_5678, 0x7FFF_FFFF, 0x7F10_0000] {
            #expect(Relay.code(inGroup: group) == nil)
        }
    }
}
