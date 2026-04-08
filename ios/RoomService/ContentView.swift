import SwiftUI

enum AppMode: String { case client, service }

struct ContentView: View {
    @StateObject private var ws = WebSocketManager()
    @State private var mode: AppMode? = nil
    @State private var serverURL = UserDefaults.standard.string(forKey: "rs_server_url") ?? ""
    @State private var showURLField: Bool

    init() {
        let saved = UserDefaults.standard.string(forKey: "rs_server_url") ?? ""
        _showURLField = State(initialValue: saved.isEmpty)
    }

    var body: some View {
        if let mode {
            Group {
                switch mode {
                case .client:  ClientRootView(ws: ws)
                case .service: ServiceRootView(ws: ws)
                }
            }
        } else {
            ModeSelectionView(serverURL: $serverURL, showURLField: $showURLField) { m in
                mode = m
                ws.connect(role: m.rawValue, serverURL: serverURL)
            }
        }
    }
}

struct ModeSelectionView: View {
    @Binding var serverURL: String
    @Binding var showURLField: Bool
    var onSelect: (AppMode) -> Void

    let accent = Color(red: 0.67, green: 0.8, blue: 0.2)
    var canConnect: Bool { !serverURL.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()

                // Brand
                VStack(spacing: 14) {
                    Text("🏨").font(.system(size: 80))
                    Text("Room Service")
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundColor(.white)
                    Text("Your personal concierge")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                }

                Spacer()

                // Server URL field
                VStack(spacing: 12) {
                    if showURLField {
                        TextField("https://your-app.onrender.com", text: $serverURL)
                            .textFieldStyle(.plain)
                            .padding(14)
                            .background(Color(white: 0.12))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Button(action: { withAnimation { showURLField.toggle() } }) {
                        Text(showURLField ? "Masquer" : "⚙ Configurer le serveur")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)

                // Mode buttons
                VStack(spacing: 12) {
                    Button(action: { onSelect(.client) }) {
                        Label("Commander", systemImage: "cup.and.saucer.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(canConnect ? accent : Color.gray.opacity(0.3))
                            .foregroundColor(canConnect ? .black : .gray)
                            .font(.system(size: 17, weight: .bold))
                            .cornerRadius(50)
                    }
                    .disabled(!canConnect)

                    Button(action: { onSelect(.service) }) {
                        Label("Dashboard service", systemImage: "tray.2.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color(white: 0.13))
                            .foregroundColor(.white)
                            .font(.system(size: 17, weight: .bold))
                            .cornerRadius(50)
                            .overlay(
                                RoundedRectangle(cornerRadius: 50)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .disabled(!canConnect)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
            }
        }
    }
}
