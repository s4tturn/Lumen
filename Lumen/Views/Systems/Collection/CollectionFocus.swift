import Observation
import SwiftUI

@MainActor @Observable
final class CollectionFocus {

    var task: CollectionTask.ID?
}
