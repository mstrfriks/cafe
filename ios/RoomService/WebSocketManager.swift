import Foundation

@MainActor
class WebSocketManager: ObservableObject {
    @Published var isConnected = false
    @Published var config: AppConfig
    @Published var orders: [ServiceOrder] = []
    @Published var confirmedOrderId: Int? = nil
    @Published var readyOrderId: Int? = nil

    private var role: String = "client"
    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var serverURL: String = ""
    private var reconnectDelay: TimeInterval = 1.0
    private var isReconnecting = false

    init() {
        serverURL = UserDefaults.standard.string(forKey: "rs_server_url") ?? ""
        if let data = UserDefaults.standard.data(forKey: "rs_config"),
           let cfg = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = cfg
        } else {
            config = .default
        }
    }

    func connect(role: String, serverURL: String) {
        self.role = role
        self.serverURL = serverURL
        UserDefaults.standard.set(serverURL, forKey: "rs_server_url")
        reconnectDelay = 1.0
        startConnection()
    }

    private func startConnection() {
        task?.cancel(with: .goingAway, reason: nil)

        var urlStr = serverURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://",  with: "ws://")
        if urlStr.hasSuffix("/") { urlStr = String(urlStr.dropLast()) }

        guard let url = URL(string: urlStr) else { return }

        task = session.webSocketTask(with: url)
        task?.resume()
        isConnected = true

        receive()
        send(["type": "register", "role": role])
        if role == "service", let cfg = configAsDict() {
            send(["type": "update_config", "config": cfg])
        }
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let message):
                    self.isConnected = true
                    self.reconnectDelay = 1.0
                    if case .string(let text) = message { self.handleMessage(text) }
                    self.receive()
                case .failure:
                    self.isConnected = false
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func scheduleReconnect() {
        guard !isReconnecting else { return }
        isReconnecting = true
        Task {
            try? await Task.sleep(nanoseconds: UInt64(reconnectDelay * 1_000_000_000))
            await MainActor.run {
                self.isReconnecting = false
                self.reconnectDelay = min(self.reconnectDelay * 2, 30)
                self.startConnection()
            }
        }
    }

    func send(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { _ in }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "config":
            if let cfgRaw = json["config"],
               let cfgData = try? JSONSerialization.data(withJSONObject: cfgRaw),
               let cfg = try? JSONDecoder().decode(AppConfig.self, from: cfgData) {
                config = cfg
                UserDefaults.standard.set(try? JSONEncoder().encode(cfg), forKey: "rs_config")
            }

        case "orders":
            if let arr = json["orders"] as? [[String: Any]] {
                orders = arr.compactMap(parseOrder)
            }

        case "new_order":
            if let d = json["order"] as? [String: Any], let o = parseOrder(d) {
                orders.insert(o, at: 0)
            }

        case "order_removed":
            if let id = json["orderId"] as? Int { orders.removeAll { $0.id == id } }

        case "order_confirmed":
            if let id = json["orderId"] as? Int { confirmedOrderId = id }

        case "order_ready":
            if let id = json["orderId"] as? Int { readyOrderId = id }

        default: break
        }
    }

    private func parseOrder(_ d: [String: Any]) -> ServiceOrder? {
        guard let id   = d["id"]    as? Int,
              let name = d["name"]  as? String,
              let drk  = d["drink"] as? String,
              let at   = d["at"]    as? TimeInterval else { return nil }
        return ServiceOrder(id: id, name: name, drink: drk,
                            at: Date(timeIntervalSince1970: at / 1000))
    }

    func placeOrder(room: String, drink: String) {
        send(["type": "order", "name": room, "drink": drink])
    }

    func markReady(orderId: Int) {
        send(["type": "ready", "orderId": orderId])
    }

    func updateConfig(_ newConfig: AppConfig) {
        config = newConfig
        if let data = try? JSONEncoder().encode(newConfig) {
            UserDefaults.standard.set(data, forKey: "rs_config")
        }
        if let cfg = configAsDict() { send(["type": "update_config", "config": cfg]) }
    }

    private func configAsDict() -> Any? {
        guard let data = try? JSONEncoder().encode(config) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
}
