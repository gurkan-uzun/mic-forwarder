    private func handleNewConnection(_ connection: NWConnection) {
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
                    print("Connection failed: \(error.localizedDescription)")
                    self?.activeConnection = nil
                    if self?.isRunning == true {
                        self?.connectionStatus = "Listening on port 12345..."
                    } else {
                        self?.connectionStatus = "Disconnected"
                    }
                case .cancelled:
                    print("Connection cancelled")
                    self?.activeConnection = nil
                    if self?.isRunning == true {
                        self?.connectionStatus = "Listening on port 12345..."
                    } else {
                        self?.connectionStatus = "Disconnected"
                    }
                default:
                    break
                }
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
    }
