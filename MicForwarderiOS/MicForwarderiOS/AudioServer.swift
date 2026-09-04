import Foundation
import AVFoundation
import Network
import Combine

class AudioServer: ObservableObject {
    @Published var isRunning = false
    @Published var connectionStatus = "Disconnected"
    @Published var volumeLevel: Float = 0.0
    @Published var currentDB: Float = -120.0 // dB readout
    @Published var noiseGateThreshold: Float = 0.01 // Noise Gate lower limit
    @Published var maxVolumeCutoff: Float = 1.0 // Loud noise upper limit
    
    private let engine = AVAudioEngine()
    private var listener: NWListener?
    private var activeConnection: NWConnection?
    
    init() {
        setupSession()
    }
    
    private func setupSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .voiceChat requires .playAndRecord category to avoid error -50
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP, .defaultToSpeaker])
            // Force hardware to 48kHz to perfectly match our Windows receiver without resampling
            try session.setPreferredSampleRate(48000.0)
            try session.setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
    }
    
    func toggleServer() {
        if isRunning {
            stopServer()
        } else {
            startServer()
        }
    }
    
    private func startServer() {
        do {
            // 1. Setup Network Listener on port 12345
            let port = NWEndpoint.Port(rawValue: 12345)!
            
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.noDelay = true
            let params = NWParameters(tls: nil, tcp: tcpOptions)
            
            listener = try NWListener(using: params, on: port)
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.connectionStatus = "Listening on port 12345..."
                    case .failed(let error):
                        self?.connectionStatus = "Listener failed: \(error.localizedDescription)"
                        self?.stopServer()
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
            
            // 2. Setup Audio Engine
            let inputNode = engine.inputNode
            
            // Enable Apple's advanced Voice Processing (removes keyboard clicks, background noise, and echo)
            do {
                try inputNode.setVoiceProcessingEnabled(true)
            } catch {
                print("Warning: Could not enable Voice Processing")
            }
            
            let inputFormat = inputNode.inputFormat(forBus: 0)
            
            // Convert to 48kHz, 16-bit Mono PCM (Standard for raw audio transport)
            guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000.0, channels: 1, interleaved: true) else {
                self.connectionStatus = "Failed to create target audio format"
                return
            }
            
            guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                self.connectionStatus = "Audio format conversion not supported on this device"
                return
            }
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] (buffer, time) in
                guard let self = self else { return }
                
                var avg: Float = 0
                if let channelData = buffer.floatChannelData?[0] {
                    var sum: Float = 0
                    for i in 0..<Int(buffer.frameLength) {
                        sum += abs(channelData[i])
                    }
                    avg = sum / Float(buffer.frameLength)
                    let db = avg > 0.000001 ? 20 * log10(avg) : -120.0
                    
                    DispatchQueue.main.async {
                        self.volumeLevel = avg
                        self.currentDB = db
                    }
                }
                
                // Convert and send audio buffer if a Windows client is connected
                if self.activeConnection?.state == .ready {
                    let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: buffer.frameCapacity)!
                    var error: NSError? = nil
                    let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                        outStatus.pointee = .haveData
                        return buffer
                    }
                    
                    converter.convert(to: outBuffer, error: &error, withInputFrom: inputBlock)
                    
                    if let channelData = outBuffer.int16ChannelData?[0] {
                        let dataLength = Int(outBuffer.frameLength) * MemoryLayout<Int16>.size
                        
                        let data: Data
                        if avg < self.noiseGateThreshold || avg > self.maxVolumeCutoff {
                            // Noise Gate or Loud Cutoff active: Send perfect silence
                            data = Data(count: dataLength)
                        } else {
                            // Threshold met: Send the actual microphone data
                            data = Data(bytes: channelData, count: dataLength)
                        }
                        
                        self.activeConnection?.send(content: data, completion: .contentProcessed({ sendError in
                            if let e = sendError {
                                print("Network Send Error: \(e)")
                            }
                        }))
                    }
                }
            }
            
            try engine.start()
            
            DispatchQueue.main.async {
                self.isRunning = true
            }
        } catch {
            connectionStatus = "Failed to start: \(error.localizedDescription)"
            stopServer()
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        if activeConnection != nil {
            // Allow only one PC to connect at a time
            connection.cancel()
            return
        }
        
        activeConnection = connection
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.connectionStatus = "Connected to Windows PC"
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
    
    private func stopServer() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        
        listener?.cancel()
        listener = nil
        
        activeConnection?.cancel()
        activeConnection = nil
        
        DispatchQueue.main.async {
            self.isRunning = false
            self.connectionStatus = "Disconnected"
            self.volumeLevel = 0
        }
    }
}
