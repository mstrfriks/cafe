import Foundation

struct Room: Identifiable, Codable, Hashable {
    var id: String
    var icon: String
    var label: String
}

struct Drink: Identifiable, Codable, Hashable {
    var id: String
    var icon: String
    var label: String
}

struct ServiceOrder: Identifiable {
    var id: Int
    var name: String
    var drink: String
    var at: Date
}

struct AppConfig: Codable {
    var rooms: [Room]
    var drinks: [Drink]

    static let `default` = AppConfig(
        rooms: [
            Room(id: "master",  icon: "👑", label: "Master Suite"),
            Room(id: "room1",   icon: "🛏️", label: "Room 1"),
            Room(id: "room2",   icon: "🛏️", label: "Room 2"),
            Room(id: "room3",   icon: "🛏️", label: "Room 3"),
            Room(id: "office1", icon: "🖥️", label: "Office 1"),
            Room(id: "dining",  icon: "🍽️", label: "Dining Room"),
            Room(id: "living",  icon: "🛋️", label: "Living Room"),
            Room(id: "gym",     icon: "🏋️", label: "Gym"),
            Room(id: "pool",    icon: "🏊", label: "Pool"),
        ],
        drinks: [
            Drink(id: "espresso",   icon: "☕", label: "Espresso"),
            Drink(id: "flat-white", icon: "☕", label: "Flat White"),
            Drink(id: "cappuccino", icon: "🥛", label: "Cappuccino"),
            Drink(id: "black-tea",  icon: "🍵", label: "Black Tea"),
            Drink(id: "green-tea",  icon: "🍵", label: "Green Tea"),
            Drink(id: "hot-choc",   icon: "🍫", label: "Hot Chocolate"),
            Drink(id: "water",      icon: "💧", label: "Still Water"),
            Drink(id: "oj",         icon: "🧃", label: "Orange Juice"),
        ]
    )
}
