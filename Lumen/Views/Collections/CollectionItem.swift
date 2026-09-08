import Foundation

// MARK: - Models

struct CollectionItem: Identifiable, Equatable {
    let id = UUID()
    let emoji: String
    let name: String
    let task: String
}

// MARK: - Card Configuration

struct Card: Identifiable {
    let id = UUID()
    let imageName: String
    let name: String
    let items: [CollectionItem]
}

let cards: [Card] = [
    Card(
        imageName: "SelfBackground",
        name: "Self",
        items: [
            CollectionItem(emoji: "🚶‍♂️", name: "Walk", task: "Take a 10-minute walk somewhere pleasant"),
            CollectionItem(emoji: "🧘‍♀️", name: "Stretch", task: "Do a full-body stretch while listening to one song"),
            CollectionItem(emoji: "🧥", name: "Clothes", task: "Take a shower and put on clothes you feel good in"),
            CollectionItem(emoji: "💧", name: "Water", task: "Drink a big glass of water"),
            CollectionItem(emoji: "✨", name: "Ritual", task: "Do one small grooming ritual you've been neglecting")
        ]
    ),
    Card(
        imageName: "SpaceBackground",
        name: "Space",
        items: [
            CollectionItem(emoji: "🧽", name: "Surface", task: "Clear one surface completely"),
            CollectionItem(emoji: "🧺", name: "Belongings", task: "Put 10 things back where they belong"),
            CollectionItem(emoji: "🛏️", name: "Bed", task: "Make your bed properly"),
            CollectionItem(emoji: "🌬️", name: "Windows", task: "Open the windows and freshen the room"),
            CollectionItem(emoji: "🕯️", name: "Beauty", task: "Make one small area feel beautiful")
        ]
    ),
    Card(
        imageName: "KitchenBackground",
        name: "Kitchen",
        items: [
            CollectionItem(emoji: "🥞", name: "Breakfast", task: "Make your favorite breakfast"),
            CollectionItem(emoji: "🥗", name: "Snack", task: "Create a snack from whatever you already have"),
            CollectionItem(emoji: "🍳", name: "Recipe", task: "Cook something you've never made before"),
            CollectionItem(emoji: "☕", name: "Drink", task: "Make yourself a really good drink"),
            CollectionItem(emoji: "🍲", name: "Memory", task: "Recreate a dish you love from memory")
        ]
    ),
    Card(
        imageName: "ConnectionBackground",
        name: "Connection",
        items: [
            CollectionItem(emoji: "📸", name: "Photo", task: "Send someone a photo that made you think of them"),
            CollectionItem(emoji: "💬", name: "Appreciation", task: "Tell someone something you genuinely appreciate about them"),
            CollectionItem(emoji: "📞", name: "Call", task: "Call someone you haven't spoken to in a while"),
            CollectionItem(emoji: "🎁", name: "Favor", task: "Do a small unexpected favor for someone"),
            CollectionItem(emoji: "⏳", name: "Presence", task: "Spend 15 minutes with someone without your phone")
        ]
    ),
    Card(
        imageName: "GrowthBackground",
        name: "Growth",
        items: [
            CollectionItem(emoji: "📖", name: "Reading", task: "Read 5 pages of something you're interested in"),
            CollectionItem(emoji: "💡", name: "Learning", task: "Learn one interesting thing and tell someone about it"),
            CollectionItem(emoji: "🎯", name: "Practice", task: "Practice a skill for 10 minutes"),
            CollectionItem(emoji: "✍️", name: "Idea", task: "Write down one idea you've been sitting on"),
            CollectionItem(emoji: "🛠️", name: "Making", task: "Spend 10 minutes making something you've been putting off")
        ]
    ),
    Card(
        imageName: "JoyBackground",
        name: "Joy",
        items: [
            CollectionItem(emoji: "🎧", name: "Music", task: "Listen to a favorite song with your eyes closed"),
            CollectionItem(emoji: "🎨", name: "Hobby", task: "Spend 15 minutes on a hobby you haven't touched recently"),
            CollectionItem(emoji: "🌸", name: "Beauty", task: "Go outside and find something beautiful"),
            CollectionItem(emoji: "🤪", name: "Silly", task: "Do something purely silly"),
            CollectionItem(emoji: "😂", name: "Laughter", task: "Rewatch a scene that always makes you laugh")
        ]
    )
]
