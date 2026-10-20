import SwiftUI

/// What the confirmation card says when a gift did not go. Every one of them keeps the card.
enum GiftRefusals {
    static func title(_ sent: GiftPost.Sent, friend: String) -> Text {
        switch sent {
        case .oneADay: Text("Today's gift has gone")
        case .unknownFriend: Text("\(friend) cannot get cards yet")
        case .notOpen: Text("Gifts are not open yet")
        case .notSignedIn: Text("Sign in to Game Center")
        case .offline, .unreachable: Text("The gift could not go just now")
        case .refused, .sent: Text("This card cannot go")
        }
    }

    static func message(_ sent: GiftPost.Sent, friend: String) -> Text {
        switch sent {
        case .oneADay: Text("One card a day. Another tomorrow.")
        case .unknownFriend:
            Text("They need to open Scopa signed in to Game Center first. Your card stays in your album.")
        case .notOpen: Text("Scopa's server does not take them yet. Your card stays in your album.")
        case .notSignedIn: Text("A gift goes from your Game Center name to theirs. Your card stays in your album.")
        case .offline, .unreachable:
            Text("Your card stays in your album until Scopa's server has the gift. It goes the next time Scopa opens online.")
        case .refused, .sent: Text("Your card stays in your album.")
        }
    }
}
