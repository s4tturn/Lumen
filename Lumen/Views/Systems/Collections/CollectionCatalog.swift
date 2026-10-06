import SwiftUI

/// Every collection in the app, and the facts derived from having them all in
/// one list.
///
/// A `static let` literal on purpose: the catalog is fixed content, so it is
/// built once, is safe to read from any isolation domain, and can never be
/// mutated behind a view's back. Adding a wheel slot means adding an entry here
/// and nothing else — every count, angle and index in the feature reads the
/// derived values below rather than restating a number.
enum CollectionCatalog {
    static let all: [Collection] = [
        Collection(
            id: .init("self"),
            title: "Self",
            background: .selfBackground,            tasks: [
                .init(id: .init("self.walk"), title: "Walk", instruction: "Take a 10-minute walk somewhere pleasant", symbol: "🚶‍♂️"),
                .init(id: .init("self.stretch"), title: "Exercise", instruction: "Exercise while listening to music", symbol: "🏋️"),
                .init(id: .init("self.clothes"), title: "Clothes", instruction: "Take a shower and put on clothes you feel good in", symbol: "🧥"),
                .init(id: .init("self.water"), title: "Water", instruction: "Drink a big glass of water", symbol: "💧"),
                .init(id: .init("self.ritual"), title: "Ritual", instruction: "Do one small grooming ritual you've been neglecting", symbol: "✨")
            ]
        ),
        Collection(
            id: .init("space"),
            title: "Space",
            background: .spaceBackground,
            tasks: [
                .init(id: .init("space.surface"), title: "Surface", instruction: "Clear one surface completely", symbol: "🧽"),
                .init(id: .init("space.belongings"), title: "Belongings", instruction: "Put 10 things back where they belong", symbol: "🧺"),
                .init(id: .init("space.bed"), title: "Bed", instruction: "Make your bed properly", symbol: "🛏️"),
                .init(id: .init("space.windows"), title: "Decoration", instruction: "Add a small decoration to your room", symbol: "🖼️"),
                .init(id: .init("space.beauty"), title: "Beauty", instruction: "Make one small area feel beautiful", symbol: "🕯️")
            ]
        ),
        Collection(
            id: .init("kitchen"),
            title: "Kitchen",
            background: .kitchenBackground,
            tasks: [
                .init(id: .init("kitchen.breakfast"), title: "Breakfast", instruction: "Make your favorite breakfast", symbol: "🥞"),
                .init(id: .init("kitchen.snack"), title: "Snack", instruction: "Create a snack from whatever you already have", symbol: "🥗"),
                .init(id: .init("kitchen.recipe"), title: "Recipe", instruction: "Cook something you've never made before", symbol: "🍳"),
                .init(id: .init("kitchen.drink"), title: "Drink", instruction: "Make yourself a really good drink", symbol: "☕"),
                .init(id: .init("kitchen.memory"), title: "Memory", instruction: "Recreate a dish you love from memory", symbol: "🍲")
            ]
        ),
        Collection(
            id: .init("connection"),
            title: "Connection",
            background: .connectionBackground,
            tasks: [
                .init(id: .init("connection.photo"), title: "Photo", instruction: "Send someone a photo that made you think of them", symbol: "📸"),
                .init(id: .init("connection.appreciation"), title: "Appreciation", instruction: "Tell someone something you genuinely appreciate about them", symbol: "💬"),
                .init(id: .init("connection.call"), title: "Call", instruction: "Call someone you haven't spoken to in a while", symbol: "📞"),
                .init(id: .init("connection.favor"), title: "Favor", instruction: "Do a small unexpected favor for someone", symbol: "🎁"),
                .init(id: .init("connection.presence"), title: "Presence", instruction: "Spend 15 minutes with someone without your phone", symbol: "⏳")
            ]
        ),
        Collection(
            id: .init("growth"),
            title: "Growth",
            background: .growthBackground,
            tasks: [
                .init(id: .init("growth.reading"), title: "Reading", instruction: "Read 5 pages of something you're interested in", symbol: "📖"),
                .init(id: .init("growth.learning"), title: "Learning", instruction: "Learn one interesting thing and tell someone about it", symbol: "💡"),
                .init(id: .init("growth.practice"), title: "Practice", instruction: "Practice a skill for 10 minutes", symbol: "🎯"),
                .init(id: .init("growth.idea"), title: "Idea", instruction: "Write down one idea you've been sitting on", symbol: "✍️"),
                .init(id: .init("growth.making"), title: "Making", instruction: "Spend 10 minutes making something you've been putting off", symbol: "🛠️")
            ]
        ),
        Collection(
            id: .init("joy"),
            title: "Joy",
            background: .joyBackground,
            tasks: [
                .init(id: .init("joy.music"), title: "Music", instruction: "Listen to a favorite song with your eyes closed", symbol: "🎧"),
                .init(id: .init("joy.hobby"), title: "Hobby", instruction: "Spend 15 minutes on a hobby you haven't touched recently", symbol: "🎨"),
                .init(id: .init("joy.beauty"), title: "Beauty", instruction: "Go outside and find something beautiful", symbol: "🌸"),
                .init(id: .init("joy.silly"), title: "Silly", instruction: "Do something purely silly", symbol: "🤪"),
                .init(id: .init("joy.laughter"), title: "Laughter", instruction: "Rewatch a scene that always makes you laugh", symbol: "😂")
            ]
        )
    ]

    /// How many slots the wheel has.
    static var count: Int { all.count }

    /// Degrees between adjacent wheel slots.
    ///
    /// Read from the catalog rather than restated, so the wheel, its detent
    /// marks and every snap calculation cannot fall out of step: adding a
    /// collection moves all three together.
    static let spacing: Double = 360 / Double(all.count)

    /// The task with this identity, and the collection that owns it.
    static func entry(for id: CollectionTask.ID) -> (Collection, CollectionTask)? {
        index[id]
    }

    /// Resolves task identities back to the content they name, **in the order
    /// given** — callers order the list, not the catalog.
    ///
    /// Identities the catalog no longer contains are dropped rather than
    /// trapped: a completion syncs to every device on the account, so one of
    /// them may be running a build whose catalog has dropped or renamed the
    /// task. Such a completion stays in the keychain and reappears if the
    /// content ever returns, but it must not break the view listing them.
    static func locate(_ ids: some Sequence<CollectionTask.ID>) -> [(Collection, CollectionTask)] {
        ids.compactMap { entry(for: $0) }
    }

    /// Identity → owning collection and task, built once on first use.
    ///
    /// Duplicates resolve to the last one rather than trapping: the keys are
    /// hand-written, and a future content edit that collides should cost one
    /// shadowed task, not a launch crash.
    private static let index: [CollectionTask.ID: (Collection, CollectionTask)] = {
        var built: [CollectionTask.ID: (Collection, CollectionTask)] = [:]
        for collection in all {
            for task in collection.tasks {
                built[task.id] = (collection, task)
            }
        }
        return built
    }()
}
