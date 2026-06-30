import Foundation
import Network

/// A tiny, defensive HTTP/1.1 endpoint built on Network.framework. Binds to
/// loopback ONLY and accepts `POST /event` with a JSON `ActivityEvent` body.
///
/// This is deliberately minimal — just enough HTTP to accept local tool events.
/// It is NOT a general-purpose web server and must never bind to 0.0.0.0.
final class ActivityServer {

    static let defaultPort: UInt16 = 7842

    private let store: ActivityStore
    private let approvals: ApprovalStore
    private let port: NWEndpoint.Port
    private let queue = DispatchQueue(label: "io.notchpulse.server", qos: .utility)
    private var listener: NWListener?

    /// Cap a single request body so a buggy/hostile client can't exhaust memory.
    private let maxBodyBytes = 64 * 1024

    init(store: ActivityStore, approvals: ApprovalStore, port: UInt16 = ActivityServer.defaultPort) {
        self.store = store
        self.approvals = approvals
        self.port = NWEndpoint.Port(rawValue: port) ?? 7842
    }

    func start() {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            // Force loopback: bind explicitly to 127.0.0.1 so we never listen on
            // any externally reachable interface.
            params.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host("127.0.0.1"),
                port: port
            )
            // No need to advertise on Bonjour or anything else.
            if let tcp = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
                tcp.version = .v4
            }

            let listener = try NWListener(using: params)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.stateUpdateHandler = { state in
                switch state {
                case .failed(let error):
                    NSLog("[NotchPulse] server failed: \(error)")
                case .ready:
                    NSLog("[NotchPulse] server listening on 127.0.0.1:\(self.port)")
                default:
                    break
                }
            }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            NSLog("[NotchPulse] server failed to start: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection handling

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    /// Recursively accumulate bytes until we have a complete request (headers +
    /// Content-Length body), then respond and close.
    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            var buffer = buffer
            if let data, !data.isEmpty {
                buffer.append(data)
            }

            if buffer.count > self.maxBodyBytes + 8 * 1024 {
                self.respond(connection, status: 413, reason: "Payload Too Large",
                             json: #"{"ok":false,"error":"body too large"}"#)
                return
            }

            if let request = HTTPRequest.parse(buffer) {
                self.process(request, on: connection)
                return
            }

            if let error {
                NSLog("[NotchPulse] receive error: \(error)")
                connection.cancel()
                return
            }
            if isComplete {
                // Connection closed before a full request arrived.
                connection.cancel()
                return
            }
            // Need more bytes.
            self.receive(on: connection, buffer: buffer)
        }
    }

    private func process(_ request: HTTPRequest, on connection: NWConnection) {
        // CORS preflight from the website.
        if request.method == "OPTIONS" {
            respond(connection, status: 204, reason: "No Content", json: "")
            return
        }
        // Detection endpoint: the website pings this to know the app is running.
        if request.method == "GET", pathOnly(request.path) == "/ping" {
            respond(connection, status: 200, reason: "OK",
                    json: #"{"ok":true,"app":"NotchPulse"}"#)
            return
        }
        // Agent asks for a decision: hook polls this until decided (or times out).
        if request.method == "GET", pathOnly(request.path) == "/decision" {
            let id = queryValue(request.path, "id") ?? ""
            Task { @MainActor in
                let json: String
                switch self.approvals.decision(for: id) {
                case .some(true): json = #"{"decision":"allow"}"#
                case .some(false): json = #"{"decision":"deny"}"#
                case .none: json = #"{"decision":"pending"}"#
                }
                self.respond(connection, status: 200, reason: "OK", json: json)
            }
            return
        }
        // Agent requests approval to run something.
        if request.method == "POST", pathOnly(request.path) == "/approve" {
            if let req = try? JSONDecoder().decode(ApprovalRequest.self, from: request.body), let id = req.id, !id.isEmpty {
                Task { @MainActor in
                    self.approvals.request(id: id, tool: req.tool ?? "Tool",
                                           command: req.command ?? req.detail ?? "",
                                           source: req.source ?? "Agent")
                }
                respond(connection, status: 200, reason: "OK", json: #"{"ok":true}"#)
            } else {
                respond(connection, status: 400, reason: "Bad Request", json: #"{"ok":false}"#)
            }
            return
        }
        guard request.method == "POST" else {
            respond(connection, status: 405, reason: "Method Not Allowed",
                    json: #"{"ok":false,"error":"use POST"}"#)
            return
        }
        guard request.path == "/event" else {
            respond(connection, status: 404, reason: "Not Found",
                    json: #"{"ok":false,"error":"unknown path"}"#)
            return
        }

        do {
            let event = try JSONDecoder().decode(ActivityEvent.self, from: request.body)
            // Hop to the main actor to mutate the store / UI.
            Task { @MainActor in
                self.store.apply(event)
            }
            respond(connection, status: 200, reason: "OK", json: #"{"ok":true}"#)
        } catch {
            respond(connection, status: 400, reason: "Bad Request",
                    json: #"{"ok":false,"error":"invalid event JSON"}"#)
        }
    }

    private func pathOnly(_ p: String) -> String {
        String(p.split(separator: "?", maxSplits: 1).first ?? "")
    }
    private func queryValue(_ p: String, _ key: String) -> String? {
        guard let q = p.split(separator: "?", maxSplits: 1).dropFirst().first else { return nil }
        for pair in q.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2, kv[0] == Substring(key) {
                return kv[1].removingPercentEncoding ?? String(kv[1])
            }
        }
        return nil
    }

    private func respond(_ connection: NWConnection, status: Int, reason: String, json: String) {
        let body = Data(json.utf8)
        var head = "HTTP/1.1 \(status) \(reason)\r\n"
        head += "Content-Type: application/json\r\n"
        head += "Content-Length: \(body.count)\r\n"
        // CORS so the NotchPulse website can detect the app and post a demo
        // event. Loopback-only + cosmetic events, so wildcard origin is fine.
        head += "Access-Control-Allow-Origin: *\r\n"
        head += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
        head += "Access-Control-Allow-Headers: Content-Type\r\n"
        head += "Connection: close\r\n"
        head += "\r\n"
        var out = Data(head.utf8)
        out.append(body)
        connection.send(content: out, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

/// Approval request body from the hook.
struct ApprovalRequest: Codable {
    var id: String?
    var tool: String?
    var command: String?
    var detail: String?
    var source: String?
}

/// Bare-minimum HTTP/1.1 request parser. Returns nil until the full message
/// (head + Content-Length body) is present in `data`.
struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data

    static func parse(_ data: Data) -> HTTPRequest? {
        // Locate the header/body boundary.
        let sep = Data("\r\n\r\n".utf8)
        guard let range = data.range(of: sep) else { return nil }

        let headData = data.subdata(in: data.startIndex..<range.lowerBound)
        guard let headString = String(data: headData, encoding: .utf8) else { return nil }

        let lines = headString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let method = String(parts[0]).uppercased()
        let path = String(parts[1])

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        let bodyStart = range.upperBound
        let available = data.distance(from: bodyStart, to: data.endIndex)
        if available < contentLength {
            return nil // wait for the rest of the body
        }
        let bodyEnd = data.index(bodyStart, offsetBy: contentLength)
        let body = data.subdata(in: bodyStart..<bodyEnd)

        return HTTPRequest(method: method, path: path, headers: headers, body: body)
    }
}
