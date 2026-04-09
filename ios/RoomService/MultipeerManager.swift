import Foundation
import Combine
import MultipeerConnectivity

class MultipeerManager: NSObject, ObservableObject {
    @Published var isConnected   = false
    @Published var config: AppConfig
    @Published var orders: [ServiceOrder] = []
    @Published var confirmedOrderId: Int? = nil
    @Published var readyOrderId:    Int? = nil
    @Published var connectedCount   = 0

    private let serviceType = "room-service"
    private let myPeerID:   MCPeerID
    private var session:    MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser:    MCNearbyServiceBrowser?

    private(set) var role = "client"
    private var nextOrderId   = 1
    private var orderPeerMap: [Int: MCPeerID] = [:]

    override init() {
        myPeerID = MCPeerID(displayName: UIDevice.current.name)

        if let data = UserDefaults.standard.data(forKey: "rs_config"),
           let cfg  = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = cfg
        } else {
            config = .default
        }

        super.init()
        session          = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }

    // MARK: - Start

    func startAsService() {
        role = "service"
        advertiser          = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    func startAsClient() {
        role = "client"
        browser          = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
        DispatchQueue.main.async {
            self.isConnected    = false
            self.connectedCount = 0
            self.orders         = []
        }
    }

    // MARK: - Sending

    func send(_ dict: [String: Any], to peers: [MCPeerID]? = nil) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
        let targets = peers ?? session.connectedPeers
        guard !targets.isEmpty else { return }
        try? session.send(data, toPeers: targets, with: .reliable)
    }

    func placeOrder(room: String, drink: String) {
        send(["type": "order", "name": room, "drink": drink])
    }

    func markReady(orderId: Int) {
        if let peer = orderPeerMap[orderId] {
            send(["type": "order_ready", "orderId": orderId], to: [peer])
            orderPeerMap.removeValue(forKey: orderId)
        }
        DispatchQueue.main.async { self.orders.removeAll { $0.id == orderId } }
    }

    func updateConfig(_ newConfig: AppConfig) {
        config = newConfig
        if let data = try? JSONEncoder().encode(newConfig) {
            UserDefaults.standard.set(data, forKey: "rs_config")
        }
        if let cfg = configAsDict() { send(["type": "config", "config": cfg]) }
    }

    // MARK: - Receiving

    private func handleMessage(_ data: Data, from peer: MCPeerID) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        DispatchQueue.main.async {
            switch type {

            case "order":
                guard self.role == "service" else { return }
                let name  = json["name"]  as? String ?? "?"
                let drink = json["drink"] as? String ?? "?"
                let id = self.nextOrderId; self.nextOrderId += 1
                self.orders.insert(ServiceOrder(id: id, name: name, drink: drink, at: Date()), at: 0)
                self.orderPeerMap[id] = peer
                self.send(["type": "order_confirmed", "orderId": id], to: [peer])

            case "order_confirmed":
                if let id = json["orderId"] as? Int { self.confirmedOrderId = id }

            case "order_ready":
                if let id = json["orderId"] as? Int { self.readyOrderId = id }

            case "config":
                if let raw     = json["config"],
                   let cfgData = try? JSONSerialization.data(withJSONObject: raw),
                   let cfg     = try? JSONDecoder().decode(AppConfig.self, from: cfgData) {
                    self.config = cfg
                    UserDefaults.standard.set(try? JSONEncoder().encode(cfg), forKey: "rs_config")
                }

            default: break
            }
        }
    }

    private func configAsDict() -> Any? {
        guard let data = try? JSONEncoder().encode(config) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
}

// MARK: - MCSessionDelegate

extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connectedCount = session.connectedPeers.count
            self.isConnected    = !session.connectedPeers.isEmpty
            if state == .connected, self.role == "service", let cfg = self.configAsDict() {
                self.send(["type": "config", "config": cfg], to: [peerID])
            }
        }
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        handleMessage(data, from: peerID)
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.connectedCount = self.session.connectedPeers.count
            self.isConnected    = !self.session.connectedPeers.isEmpty
        }
    }
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}
