import Foundation
import ScopaCore
import ScopaRelay

/// The reconnect banner in each of its states, over a table dealt on this phone, since a real
/// drop needs two phones and a network to pull out from under them.
///
/// `-reconnect lost` is this phone's own line given up on, with Reconnect; `reconnecting` the
/// capsule while it mends; `waiting` a room's host gone quiet; `gone` the same host past the
/// wait; `gcGone` and `nearbyGone` a host who cannot come back over Game Center or the Wi-Fi;
/// `rejoin` the lobby offering a room game the app was closed in the middle of.
extension DebugLaunch {
    @MainActor
    static func applyReconnect(to store: TableStore) {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-reconnect"), let word = arguments[safe: index + 1] else { return }
        let host = "Marco"
        if word == "rejoin" {
            let me = Player(id: PlayerID(rawValue: Device.id), name: store.playerName)
            store.connection.pretend(RejoinTicket(code: "K7QX", player: me, hostName: host))
            return
        }
        guard let (state, carrier) = pretendLink(word, host: host) else { return }
        store.playOnThisDevice(seats: [.person(name: store.playerName), .bot(name: host)], teams: false)
        store.connection.pretend(state, carrier: carrier)
        #endif
    }

    #if DEBUG
    private static func pretendLink(_ word: String, host: String) -> (TableLink.State, TableLink.Carrier)? {
        switch word {
        case "reconnecting": (.reconnecting, .relay)
        case "lost": (.lost, .relay)
        case "waiting": (.hostAway(host), .relay)
        case "gone": (.hostGone(host), .relay)
        case "gcWaiting": (.hostAway(host), .gameCenter(phones: 2))
        case "gcGone": (.hostGone(host), .gameCenter(phones: 4))
        case "nearbyGone": (.hostGone(host), .nearby)
        default: nil
        }
    }
    #endif
}
