import SwiftUI

// MARK: - Root

struct ServiceRootView: View {
    @ObservedObject var ws: WebSocketManager
    @State private var showSettings = false

    let accent = Color(red: 0.67, green: 0.8, blue: 0.2)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("🏨 Room Service")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.white)
                    Text("Service Dashboard")
                        .font(.caption).foregroundColor(.gray)
                }

                Spacer()

                if !ws.orders.isEmpty {
                    Text("\(ws.orders.count)")
                        .font(.system(size: 15, weight: .heavy))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(accent).foregroundColor(.black)
                        .clipShape(Capsule())
                }

                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17))
                        .frame(width: 40, height: 40)
                        .background(Color(white: 0.13))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                }

                Circle()
                    .fill(ws.isConnected ? accent : .red)
                    .frame(width: 10, height: 10)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(Color(white: 0.09))

            Divider().background(Color.white.opacity(0.08))

            if ws.orders.isEmpty {
                VStack(spacing: 14) {
                    Text("🛎️").font(.system(size: 56))
                    Text("En attente de commandes…")
                        .foregroundColor(.gray).font(.title3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(ws.orders) { order in
                            OrderCard(order: order, accent: accent) {
                                ws.markReady(orderId: order.id)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(white: 0.05).ignoresSafeArea())
        .sheet(isPresented: $showSettings) {
            SettingsView(ws: ws)
        }
    }
}

// MARK: - Order Card

struct OrderCard: View {
    let order: ServiceOrder
    let accent: Color
    var onReady: () -> Void

    @State private var timeText = ""

    var body: some View {
        HStack(spacing: 16) {
            Text("☕").font(.system(size: 38))

            VStack(alignment: .leading, spacing: 4) {
                Text(order.name)
                    .font(.caption.bold()).kerning(0.6)
                    .foregroundColor(accent)
                    .textCase(.uppercase)
                Text(order.drink)
                    .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                Text(timeText)
                    .font(.caption).foregroundColor(.gray)
            }

            Spacer()

            Button(action: onReady) {
                Text("Prêt ✓")
                    .font(.system(size: 15, weight: .heavy))
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(accent).foregroundColor(.black)
                    .clipShape(Capsule())
            }
        }
        .padding(18)
        .background(Color(white: 0.125))
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.07), lineWidth: 1))
        .onAppear { updateTime() }
    }

    func updateTime() {
        let s = Int(-order.at.timeIntervalSinceNow)
        timeText = s < 60 ? "\(s)s" : "\(s / 60)min"
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { updateTime() }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @ObservedObject var ws: WebSocketManager
    @Environment(\.dismiss) var dismiss

    @State private var editRooms:  [Room]  = []
    @State private var editDrinks: [Drink] = []
    @State private var newRoomIcon  = "🛏️"
    @State private var newRoomLabel = ""
    @State private var newDrinkIcon  = "☕"
    @State private var newDrinkLabel = ""

    let accent = Color(red: 0.67, green: 0.8, blue: 0.2)

    var body: some View {
        NavigationStack {
            List {
                Section("PIÈCES / TABLES") {
                    ForEach(editRooms) { room in
                        Label(room.label, title: {
                            Text(room.label).foregroundColor(.primary)
                        }, icon: { Text(room.icon) })
                    }
                    .onDelete { idx in editRooms.remove(atOffsets: idx) }
                    .onMove  { from, to in editRooms.move(fromOffsets: from, toOffset: to) }

                    HStack {
                        TextField("🛏️", text: $newRoomIcon).frame(width: 42).multilineTextAlignment(.center)
                        TextField("Nom de la pièce", text: $newRoomLabel)
                        Button { addRoom() } label: {
                            Image(systemName: "plus.circle.fill").foregroundColor(accent)
                        }
                        .disabled(newRoomLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section("BOISSONS") {
                    ForEach(editDrinks) { drink in
                        Label(drink.label, title: {
                            Text(drink.label).foregroundColor(.primary)
                        }, icon: { Text(drink.icon) })
                    }
                    .onDelete { idx in editDrinks.remove(atOffsets: idx) }
                    .onMove  { from, to in editDrinks.move(fromOffsets: from, toOffset: to) }

                    HStack {
                        TextField("☕", text: $newDrinkIcon).frame(width: 42).multilineTextAlignment(.center)
                        TextField("Nom de la boisson", text: $newDrinkLabel)
                        Button { addDrink() } label: {
                            Image(systemName: "plus.circle.fill").foregroundColor(accent)
                        }
                        .disabled(newDrinkLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading)  { EditButton() }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sauvegarder") {
                        ws.updateConfig(AppConfig(rooms: editRooms, drinks: editDrinks))
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .onAppear {
            editRooms  = ws.config.rooms
            editDrinks = ws.config.drinks
        }
    }

    func addRoom() {
        let icon = newRoomIcon.trimmingCharacters(in: .whitespaces).isEmpty ? "🛏️" : newRoomIcon
        editRooms.append(Room(id: "r\(Int(Date().timeIntervalSince1970))", icon: icon, label: newRoomLabel.trimmingCharacters(in: .whitespaces)))
        newRoomLabel = ""
        newRoomIcon  = "🛏️"
    }

    func addDrink() {
        let icon = newDrinkIcon.trimmingCharacters(in: .whitespaces).isEmpty ? "☕" : newDrinkIcon
        editDrinks.append(Drink(id: "d\(Int(Date().timeIntervalSince1970))", icon: icon, label: newDrinkLabel.trimmingCharacters(in: .whitespaces)))
        newDrinkLabel = ""
        newDrinkIcon  = "☕"
    }
}
