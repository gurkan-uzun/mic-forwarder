import re

with open("MicForwarderiOS/MicForwarderiOS/AudioServer.swift", "r") as f:
    content = f.read()

# Replace activeConnection with an array
content = content.replace("private var activeConnection: NWConnection?", "private var activeTCPConnections: [NWConnection] = []")

# Update handleNewConnection
old_handle = """    private func handleNewConnection(_ connection: NWConnection) {
        if activeConnection != nil {
            connection.cancel()
            return
        }
        
        activeConnection = connection
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.connectionStatus = "Connected to Windows PC (USB)"
                case .failed(let error):
                    print("Connection failed: \\(error.localizedDescription)")
                    self?.activeConnection = nil
                    if self?.isRunning == true {
                        self?.connectionStatus = "Listening on USB:12347 Wi-Fi:12345..."
                    } else {
                        self?.connectionStatus = "Disconnected"
                    }
                case .cancelled:
                    print("Connection cancelled")
                    self?.activeConnection = nil
                    if self?.isRunning == true {
                        self?.connectionStatus = "Listening on USB:12347 Wi-Fi:12345..."
                    } else {
                        self?.connectionStatus = "Disconnected"
                    }
                default:
                    break
                }
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
    }"""

new_handle = """    private func handleNewConnection(_ connection: NWConnection) {
        activeTCPConnections.append(connection)
        
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.connectionStatus = "Connected to Windows PC (USB) [\\((self?.activeTCPConnections.count ?? 0))]"
                case .failed(let error):
                    print("Connection failed: \\(error.localizedDescription)")
                    self?.activeTCPConnections.removeAll(where: { $0 === connection })
                    if self?.activeTCPConnections.isEmpty == true {
                        self?.connectionStatus = self?.isRunning == true ? "Listening on USB:12347 Wi-Fi:12345..." : "Disconnected"
                    }
                case .cancelled:
                    print("Connection cancelled")
                    self?.activeTCPConnections.removeAll(where: { $0 === connection })
                    if self?.activeTCPConnections.isEmpty == true {
                        self?.connectionStatus = self?.isRunning == true ? "Listening on USB:12347 Wi-Fi:12345..." : "Disconnected"
                    }
                default:
                    break
                }
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
    }"""

if old_handle in content:
    content = content.replace(old_handle, new_handle)
else:
    print("Could not find handleNewConnection")

# Replace stopServer
content = content.replace("activeConnection?.cancel()\n        activeConnection = nil", "activeTCPConnections.forEach { $0.cancel() }\n        activeTCPConnections.removeAll()")

# Replace processAudioBuffer activeConnection checks
old_process = """                if self.activeConnection?.state == .ready {
                    self.activeConnection?.send(content: data, completion: .contentProcessed({ error in if let e = error { print("Send error: \\(e)") } }))
                }"""
new_process = """                for conn in self.activeTCPConnections where conn.state == .ready {
                    conn.send(content: data, completion: .contentProcessed({ _ in }))
                }"""
if old_process in content:
    content = content.replace(old_process, new_process)

old_check = "if self.activeConnection?.state == .ready || self.activeUDPConnection?.state == .ready {"
new_check = "if !self.activeTCPConnections.isEmpty || self.activeUDPConnection?.state == .ready {"
content = content.replace(old_check, new_check)

with open("MicForwarderiOS/MicForwarderiOS/AudioServer.swift", "w") as f:
    f.write(content)
print("Done")
