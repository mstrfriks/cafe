import SwiftUI

// MARK: - Root

struct ClientRootView: View {
    @ObservedObject var ws: WebSocketManager
    @State private var selectedRoom: Room? = nil
    @State private var screen: Screen = .rooms
    @State private var showReady = false

    enum Screen { case rooms, order, confirmed }

    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()

            switch screen {
            case .rooms:
                RoomSelectionView(ws: ws) { room in
                    selectedRoom = room
                    ws.confirmedOrderId = nil
                    screen = .order
                }
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))

            case .order:
                if let room = selectedRoom {
                    OrderView(ws: ws, room: room,
                              onBack: { screen = .rooms },
                              onConfirmed: { screen = .confirmed })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                }

            case .confirmed:
                ConfirmView { screen = .order }
                    .transition(.opacity)
            }

            if showReady {
                ReadyOverlay { showReady = false; screen = .order }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: screen)
        .onChange(of: ws.readyOrderId) { id in if id != nil { showReady = true } }
    }
}

// MARK: - Room Selection

struct RoomSelectionView: View {
    @ObservedObject var ws: WebSocketManager
    var onSelect: (Room) -> Void

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    let accent  = Color(red: 0.67, green: 0.8, blue: 0.2)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choisissez votre pièce")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Spacer()
                Circle()
                    .fill(ws.isConnected ? accent : .gray)
                    .frame(width: 10, height: 10)
            }
            .padding()

            Divider().background(Color.white.opacity(0.08))

            ScrollView {
                LazyVGrid(columns: columns, spacing: 11) {
                    ForEach(ws.config.rooms) { room in
                        Button { onSelect(room) } label: {
                            VStack(spacing: 9) {
                                Text(room.icon).font(.system(size: 32))
                                Text(room.label)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .padding(.horizontal, 6)
                            .background(Color(white: 0.125))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1.5)
                            )
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Order

struct OrderView: View {
    @ObservedObject var ws: WebSocketManager
    let room: Room
    var onBack: () -> Void
    var onConfirmed: () -> Void

    @State private var quantities: [String: Int] = [:]

    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    let accent  = Color(red: 0.67, green: 0.8, blue: 0.2)

    var total: Int { quantities.values.reduce(0, +) }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Text("Room Service")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Spacer()
                Button(action: onBack) {
                    HStack(spacing: 5) {
                        Text(room.icon)
                        Text(room.label)
                            .font(.caption.bold())
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(accent.opacity(0.13))
                    .foregroundColor(accent)
                    .cornerRadius(50)
                    .overlay(RoundedRectangle(cornerRadius: 50).stroke(accent.opacity(0.3), lineWidth: 1))
                }
            }
            .padding()

            Divider().background(Color.white.opacity(0.08))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("QUE SOUHAITEZ-VOUS ?")
                        .font(.caption.bold()).kerning(1).foregroundColor(.gray)

                    LazyVGrid(columns: columns, spacing: 11) {
                        ForEach(ws.config.drinks) { drink in
                            DrinkCard(
                                drink: drink,
                                qty: quantities[drink.id] ?? 0,
                                accent: accent
                            ) { delta in
                                let q = max(0, min(99, (quantities[drink.id] ?? 0) + delta))
                                quantities[drink.id] = q
                            }
                        }
                    }
                }
                .padding()
            }

            // Footer
            VStack {
                Button(action: placeOrder) {
                    Text(total > 0
                         ? "Commander · \(total) boisson\(total > 1 ? "s" : "")"
                         : "Choisissez une boisson")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(total > 0 && ws.isConnected ? accent : Color.gray.opacity(0.3))
                        .foregroundColor(total > 0 && ws.isConnected ? .black : .gray)
                        .font(.system(size: 17, weight: .bold))
                        .cornerRadius(50)
                }
                .disabled(total == 0 || !ws.isConnected)
            }
            .padding(.horizontal).padding(.bottom, 28)
        }
        .onAppear {
            ws.config.drinks.forEach { quantities[$0.id] = 0 }
        }
        .onChange(of: ws.config.drinks) { _ in
            ws.config.drinks.forEach { d in
                if quantities[d.id] == nil { quantities[d.id] = 0 }
            }
        }
        .onChange(of: ws.confirmedOrderId) { id in if id != nil { onConfirmed() } }
    }

    func placeOrder() {
        var items: [String] = []
        for d in ws.config.drinks {
            let q = quantities[d.id] ?? 0
            if q > 0 { items.append(q > 1 ? "\(d.label) ×\(q)" : d.label) }
        }
        guard !items.isEmpty else { return }
        ws.placeOrder(room: room.label, drink: items.joined(separator: ", "))
    }
}

// MARK: - Drink Card

struct DrinkCard: View {
    let drink: Drink
    let qty: Int
    let accent: Color
    var onChange: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(drink.icon).font(.system(size: 28))
                Text(drink.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture { onChange(qty == 0 ? 1 : -qty) }

            if qty > 0 {
                Divider().background(Color.white.opacity(0.1)).padding(.top, 10)
                HStack {
                    Spacer()
                    Button { onChange(-1) } label: {
                        Image(systemName: "minus")
                            .frame(width: 34, height: 34)
                            .background(Color(white: 0.15))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    Text("\(qty)")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(accent)
                        .frame(minWidth: 28)
                    Button { onChange(1) } label: {
                        Image(systemName: "plus")
                            .frame(width: 34, height: 34)
                            .background(Color(white: 0.15))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.top, 10)
            }
        }
        .padding(16)
        .background(qty > 0 ? accent.opacity(0.1) : Color(white: 0.125))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(qty > 0 ? accent : Color.white.opacity(0.1), lineWidth: 1.5)
        )
    }
}

// MARK: - Confirm

struct ConfirmView: View {
    var onDismiss: () -> Void
    let accent = Color(red: 0.67, green: 0.8, blue: 0.2)

    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(accent).frame(width: 100, height: 100)
                    Text("✓")
                        .font(.system(size: 48, weight: .heavy))
                        .foregroundColor(.black)
                }
                Text("Commande envoyée !")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(.white)
                Text("Votre commande est en cours de préparation.")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { onDismiss() }
        }
    }
}

// MARK: - Ready Overlay

struct ReadyOverlay: View {
    var onDismiss: () -> Void
    let accent = Color(red: 0.67, green: 0.8, blue: 0.2)

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("☕").font(.system(size: 76))
                Text("C'est prêt !").font(.system(size: 32, weight: .heavy)).foregroundColor(.white)
                Text("Votre commande arrive.").foregroundColor(.gray)
                Button(action: onDismiss) {
                    Text("Merci !")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(accent)
                        .foregroundColor(.black)
                        .font(.system(size: 17, weight: .bold))
                        .cornerRadius(50)
                }
                .padding(.horizontal)
            }
            .padding(36)
            .background(Color(white: 0.1))
            .cornerRadius(28)
            .padding(.horizontal, 24)
        }
    }
}
