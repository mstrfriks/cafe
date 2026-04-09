import SwiftUI

enum AppMode: String { case client, service }

struct ContentView: View {
    @StateObject private var mp = MultipeerManager()
    @State private var mode: AppMode? = nil

    var body: some View {
        Group {
            if let mode = mode {
                switch mode {
                case .client:  ClientRootView(mp: mp)
                case .service: ServiceRootView(mp: mp)
                }
            } else {
                ModeSelectionView { m in
                    mode = m
                    if m == .service { mp.startAsService() }
                    else             { mp.startAsClient()  }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct ModeSelectionView: View {
    var onSelect: (AppMode) -> Void
    let accent = Color(red: 0.67, green: 0.8, blue: 0.2)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    Text("🏨").font(.system(size: 80))
                    Text("Room Service")
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundColor(.white)
                    Text("Your personal concierge")
                        .foregroundColor(.gray).font(.subheadline)
                }

                Spacer()

                Text("Assurez-vous d'être sur le même WiFi")
                    .font(.caption).foregroundColor(.gray)
                    .padding(.bottom, 20)

                VStack(spacing: 12) {
                    Button(action: { onSelect(.client) }) {
                        Label("Commander", systemImage: "cup.and.saucer.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(accent)
                            .foregroundColor(.black)
                            .font(.system(size: 17, weight: .bold))
                            .cornerRadius(50)
                    }

                    Button(action: { onSelect(.service) }) {
                        Label("Dashboard service", systemImage: "tray.2.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color(white: 0.13))
                            .foregroundColor(.white)
                            .font(.system(size: 17, weight: .bold))
                            .cornerRadius(50)
                            .overlay(RoundedRectangle(cornerRadius: 50).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
            }
        }
    }
}
