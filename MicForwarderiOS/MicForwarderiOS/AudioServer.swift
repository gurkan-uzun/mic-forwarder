import Foundation
import Network
import AVFoundation
import Accelerate
import Combine

enum VoiceFilter: String, CaseIterable {
    case normal = "Normal"
    case chipmunk = "Chipmunk"
    case monster = "Monster"
    case robot = "Robot"
    case radio = "Radio"
    case cave = "Cave"
    case alien = "Alien"
    case vader = "Darth Vader"
    case echo = "Echo"
    case megaphone = "Megaphone"
    case underwater = "Underwater"
    case demon = "Demon"
}

class AudioServer: ObservableObject {
    @Published var isRunning = false
    @Published var connectionStatus = "Disconnected"
    @Published var volumeLevel: Float = 0.0
    @Published var currentDB: Float = -120.0
    @Published var noiseGateThreshold: Float = 0.01
    @Published var maxVolumeCutoff: Float = 1.0
    @Published var microphoneGain: Float = 1.0
    @Published var localIP: String = "Fetching IP..."
    @Published var frequencyBuckets: [Float] = Array(repeating: 0.0, count: 40)
    @Published var isVisualizerEnabled: Bool = true
    
    @Published var activeFilter: VoiceFilter = .normal {
        didSet {
            applyFilterSettings()
        }
    }
    
    // FFT Properties
    private let fftSize: Int = 1024
    private lazy var log2n = vDSP_Length(log2(Float(fftSize)))
    private lazy var fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
    
    // Audio Engine Nodes
    private let engine = AVAudioEngine()
    private let pitchNode = AVAudioUnitTimePitch()
    private let distortionNode = AVAudioUnitDistortion()
    private let reverbNode = AVAudioUnitReverb()
    private let delayNode = AVAudioUnitDelay()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 1)
    
    private var listener: NWListener?
    private var udpListener: NWListener?
    var activeConnection: NWConnection?
    var activeUDPConnection: NWConnection?
    
    init() {
        setupSession()
        fetchLocalIP()
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }
    
    private func setupSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP, .defaultToSpeaker])
            try session.setPreferredSampleRate(48000.0)
            // We will activate the session only when startServer is called.
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
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Network Listeners
            listener = try NWListener(using: .tcp, on: 12345)
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            listener?.start(queue: .global(qos: .userInitiated))
            
            udpListener = try NWListener(using: .udp, on: 12345)
            udpListener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewUDPConnection(connection)
            }
            udpListener?.start(queue: .global(qos: .userInitiated))
            
            // Audio Engine Pipeline
            let inputNode = engine.inputNode
            let mainMixer = engine.mainMixerNode
            let inputFormat = inputNode.inputFormat(forBus: 0)
            
            engine.attach(pitchNode)
            engine.attach(distortionNode)
            engine.attach(reverbNode)
            engine.attach(delayNode)
            engine.attach(eqNode)
            
            // Connect the chain: input -> pitch -> distortion -> delay -> reverb -> eq -> mainMixer
            engine.connect(inputNode, to: pitchNode, format: inputFormat)
            engine.connect(pitchNode, to: distortionNode, format: inputFormat)
            engine.connect(distortionNode, to: delayNode, format: inputFormat)
            engine.connect(delayNode, to: reverbNode, format: inputFormat)
            engine.connect(reverbNode, to: eqNode, format: inputFormat)
            engine.connect(eqNode, to: mainMixer, format: inputFormat)
            
            // Important: mute output so we don't cause feedback from the speaker
            mainMixer.outputVolume = 0.0
            
            applyFilterSettings()
            
            let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000.0, channels: 1, interleaved: false)!
            guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                self.connectionStatus = "Audio format conversion not supported"
                return
            }
            
            // Install Tap on the EQ Node (the last node in our chain before the mixer)
            eqNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] (buffer, time) in
                guard let self = self else { return }
                self.processAudioBuffer(buffer: buffer, converter: converter, targetFormat: targetFormat)
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
    
    private func processAudioBuffer(buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        var avg: Float = 0
        if let channelData = buffer.floatChannelData?[0] {
            var sum: Float = 0
            let actualFrameLength = Int(buffer.frameLength)
            for i in 0..<actualFrameLength { sum += abs(channelData[i]) }
            avg = sum / Float(actualFrameLength)
            let db = avg > 0.000001 ? 20 * log10(avg) : -120.0
            
            if self.isVisualizerEnabled {
                var paddedData = [Float](repeating: 0.0, count: self.fftSize)
                let copyCount = min(actualFrameLength, self.fftSize)
                for i in 0..<copyCount { paddedData[i] = channelData[i] }
                
                var real = [Float](repeating: 0.0, count: self.fftSize / 2)
                var imag = [Float](repeating: 0.0, count: self.fftSize / 2)
                var splitComplex = DSPSplitComplex(realp: &real, imagp: &imag)
                
                paddedData.withUnsafeBufferPointer { ptr in
                    ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: self.fftSize / 2) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(self.fftSize / 2))
                    }
                }
                
                if let setup = self.fftSetup {
                    vDSP_fft_zrip(setup, &splitComplex, 1, self.log2n, FFTDirection(FFT_FORWARD))
                    var magnitudes = [Float](repeating: 0.0, count: self.fftSize / 2)
                    vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(self.fftSize / 2))
                    
                    var normalizedMags = [Float](repeating: 0.0, count: self.fftSize / 2)
                    var scalingFactor: Float = 1.0 / Float(self.fftSize * 2)
                    vDSP_vsmul(magnitudes, 1, &scalingFactor, &normalizedMags, 1, vDSP_Length(self.fftSize / 2))
                    vvsqrtf(&normalizedMags, normalizedMags, [Int32(self.fftSize / 2)])
                    
                    let binCount = self.fftSize / 2
                    let binsPerBucket = binCount / 40
                    var buckets = [Float](repeating: 0.0, count: 40)
                    
                    for i in 0..<40 {
                        var maxMag: Float = 0.0
                        let startBin = i * binsPerBucket
                        for j in startBin..<(startBin + binsPerBucket) {
                            if normalizedMags[j] > maxMag { maxMag = normalizedMags[j] }
                        }
                        buckets[i] = min(maxMag * 5.0, 1.0)
                    }
                    DispatchQueue.main.async {
                        self.volumeLevel = avg
                        self.currentDB = db
                        self.frequencyBuckets = buckets
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.volumeLevel = avg
                    self.currentDB = db
                }
            }
        }
        
        if self.activeConnection?.state == .ready || self.activeUDPConnection?.state == .ready {
            let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: buffer.frameCapacity)!
            var error: NSError? = nil
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            converter.convert(to: outBuffer, error: &error, withInputFrom: inputBlock)
            
            if let channelData = outBuffer.int16ChannelData?[0] {
                let dataLength = Int(outBuffer.frameLength)
                let gain = self.microphoneGain
                if gain > 1.0 {
                    for i in 0..<dataLength {
                        let amplified = Float(channelData[i]) * gain
                        let clamped = min(max(amplified, Float(Int16.min)), Float(Int16.max))
                        channelData[i] = Int16(clamped)
                    }
                }
                
                let dataLengthInBytes = dataLength * MemoryLayout<Int16>.size
                let data: Data
                if avg < self.noiseGateThreshold || avg > self.maxVolumeCutoff {
                    data = Data(count: dataLengthInBytes)
                } else {
                    data = Data(bytes: channelData, count: dataLengthInBytes)
                }
                
                if self.activeConnection?.state == .ready {
                    self.activeConnection?.send(content: data, completion: .contentProcessed({ _ in }))
                }
                if self.activeUDPConnection?.state == .ready {
                    self.activeUDPConnection?.send(content: data, completion: .contentProcessed({ _ in }))
                }
            }
        }
    }
    
    private func applyFilterSettings() {
        // Reset all
        pitchNode.bypass = true
        distortionNode.bypass = true
        reverbNode.bypass = true
        delayNode.bypass = true
        eqNode.bypass = true
        
        switch activeFilter {
        case .normal:
            break
            
        case .chipmunk:
            pitchNode.bypass = false
            pitchNode.pitch = 1000
            
        case .monster:
            pitchNode.bypass = false
            pitchNode.pitch = -800
            
        case .robot:
            delayNode.bypass = false
            delayNode.delayTime = 0.015
            delayNode.feedback = 60
            delayNode.wetDryMix = 50
            
        case .radio:
            distortionNode.bypass = false
            distortionNode.loadFactoryPreset(.speechRadioTower)
            distortionNode.wetDryMix = 70
            
        case .cave:
            reverbNode.bypass = false
            reverbNode.loadFactoryPreset(.largeHall)
            reverbNode.wetDryMix = 60
            
        case .alien:
            distortionNode.bypass = false
            distortionNode.loadFactoryPreset(.speechAlienChatter)
            distortionNode.wetDryMix = 50
            
        case .vader:
            pitchNode.bypass = false
            pitchNode.pitch = -600
            reverbNode.bypass = false
            reverbNode.loadFactoryPreset(.smallRoom)
            reverbNode.wetDryMix = 40
            
        case .echo:
            delayNode.bypass = false
            delayNode.delayTime = 0.4
            delayNode.feedback = 40
            delayNode.wetDryMix = 50
            
        case .megaphone:
            distortionNode.bypass = false
            distortionNode.loadFactoryPreset(.speechRadioTower)
            distortionNode.wetDryMix = 100
            
        case .underwater:
            eqNode.bypass = false
            eqNode.bands[0].filterType = .lowPass
            eqNode.bands[0].frequency = 400
            eqNode.bands[0].bypass = false
            
        case .demon:
            pitchNode.bypass = false
            pitchNode.pitch = -1200
            reverbNode.bypass = false
            reverbNode.loadFactoryPreset(.largeHall)
            reverbNode.wetDryMix = 50
            distortionNode.bypass = false
            distortionNode.preGain = 5
        }
    }
    
    // ... Networking Code ...
    private func handleNewConnection(_ connection: NWConnection) {
        if activeConnection != nil { connection.cancel(); return }
        activeConnection = connection
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready: self?.connectionStatus = "Connected to Windows PC"
                case .failed(let error):
                    print("Connection failed: \(error)")
                    self?.activeConnection = nil
                    self?.connectionStatus = self?.isRunning == true ? "Listening on port 12345..." : "Disconnected"
                case .cancelled:
                    self?.activeConnection = nil
                    self?.connectionStatus = self?.isRunning == true ? "Listening on port 12345..." : "Disconnected"
                default: break
                }
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
    }
    
    private func handleNewUDPConnection(_ connection: NWConnection) {
        if activeUDPConnection != nil { activeUDPConnection?.cancel() }
        activeUDPConnection = connection
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready: self?.connectionStatus = "UDP Connected (Wi-Fi)"
                case .failed(_), .cancelled:
                    self?.activeUDPConnection = nil
                    if self?.activeConnection == nil && self?.isRunning == true {
                        self?.connectionStatus = "Listening on port 12345..."
                    }
                default: break
                }
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
        receiveUDPLoop(on: connection)
    }
    
    private func receiveUDPLoop(on connection: NWConnection) {
        connection.receiveMessage { [weak self] (content, context, isComplete, error) in
            if error == nil { self?.receiveUDPLoop(on: connection) }
        }
    }
    
    private func stopServer() {
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        eqNode.removeTap(onBus: 0)
        listener?.cancel()
        listener = nil
        udpListener?.cancel()
        udpListener = nil
        activeConnection?.cancel()
        activeConnection = nil
        activeUDPConnection?.cancel()
        activeUDPConnection = nil
        DispatchQueue.main.async {
            self.isRunning = false
            self.connectionStatus = "Disconnected"
            self.volumeLevel = 0
        }
    }
    
    private func fetchLocalIP() {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { continue }
                if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                    if String(cString: interface.ifa_name) == "en0" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                        break
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        DispatchQueue.main.async { self.localIP = address ?? "Wi-Fi Disconnected" }
    }
}
