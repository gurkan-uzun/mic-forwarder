import Foundation

protocol TCPServerDelegate: AnyObject {
    func tcpServer(_ server: TCPServer, didAccept client: Int32)
    func tcpServer(_ server: TCPServer, didDisconnect client: Int32)
}

class TCPServer {
    private var serverSocket: Int32 = -1
    private var clientSocket: Int32 = -1
    private var listenSource: DispatchSourceRead?
    private var clientSource: DispatchSourceRead?
    
    weak var delegate: TCPServerDelegate?
    
    func start(port: UInt16) throws {
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else { throw NSError(domain: "TCPServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create socket"]) }
        
        var optval: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &optval, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEPORT, &optval, socklen_t(MemoryLayout<Int32>.size))
        
        var serverAddr = sockaddr_in()
        serverAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        serverAddr.sin_family = sa_family_t(AF_INET)
        serverAddr.sin_port = port.bigEndian
        serverAddr.sin_addr.s_addr = INADDR_ANY.bigEndian // 0.0.0.0
        
        let bindResult = withUnsafePointer(to: &serverAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult >= 0 else { throw NSError(domain: "TCPServer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to bind socket"]) }
        
        let listenResult = listen(serverSocket, 5)
        guard listenResult >= 0 else { throw NSError(domain: "TCPServer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to listen on socket"]) }
        
        listenSource = DispatchSource.makeReadSource(fileDescriptor: serverSocket, queue: .global(qos: .userInitiated))
        listenSource?.setEventHandler { [weak self] in
            self?.acceptConnection()
        }
        listenSource?.resume()
    }
    
    private func acceptConnection() {
        var clientAddr = sockaddr_in()
        var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        let newClient = withUnsafeMutablePointer(to: &clientAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                accept(serverSocket, $0, &clientAddrLen)
            }
        }
        
        guard newClient >= 0 else { return }
        
        // Close existing client if any
        if clientSocket >= 0 {
            close(clientSocket)
            clientSource?.cancel()
            clientSource = nil
            DispatchQueue.main.async { self.delegate?.tcpServer(self, didDisconnect: self.clientSocket) }
        }
        
        clientSocket = newClient
        
        // Set no delay
        var optval: Int32 = 1
        setsockopt(clientSocket, IPPROTO_TCP, TCP_NODELAY, &optval, socklen_t(MemoryLayout<Int32>.size))
        
        clientSource = DispatchSource.makeReadSource(fileDescriptor: clientSocket, queue: .global(qos: .userInitiated))
        clientSource?.setEventHandler { [weak self] in
            guard let self = self else { return }
            var buffer = [UInt8](repeating: 0, count: 1024)
            let bytesRead = read(self.clientSocket, &buffer, buffer.count)
            if bytesRead <= 0 {
                // Disconnected
                let oldClient = self.clientSocket
                self.clientSocket = -1
                self.clientSource?.cancel()
                self.clientSource = nil
                close(oldClient)
                DispatchQueue.main.async { self.delegate?.tcpServer(self, didDisconnect: oldClient) }
            }
        }
        clientSource?.resume()
        
        DispatchQueue.main.async { self.delegate?.tcpServer(self, didAccept: newClient) }
    }
    
    func send(data: Data) {
        guard clientSocket >= 0 else { return }
        data.withUnsafeBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            _ = write(clientSocket, baseAddress, data.count)
        }
    }
    
    func stop() {
        if clientSocket >= 0 {
            close(clientSocket)
            clientSocket = -1
        }
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
        clientSource?.cancel()
        clientSource = nil
        listenSource?.cancel()
        listenSource = nil
    }
}
