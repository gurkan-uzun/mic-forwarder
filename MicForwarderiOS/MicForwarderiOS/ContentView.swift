import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var audioServer = AudioServer()
    
    var body: some View {
        TabView {
            // TAB 1: MIXER
            MixerView(audioServer: audioServer)
                .tabItem {
                    Image(systemName: "slider.horizontal.3")
                    Text("Mixer")
                }
            
            // TAB 2: EFFECTS
            EffectsView(audioServer: audioServer)
                .tabItem {
                    Image(systemName: "wand.and.stars")
                    Text("Effects")
                }
        }
    }
}

// MARK: - Mixer Tab
struct MixerView: View {
    @ObservedObject var audioServer: AudioServer
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                Text("Mic Forwarder")
                    .font(.largeTitle)
                    .bold()
                
                Text(audioServer.connectionStatus)
                    .font(.headline)
                    .foregroundColor(audioServer.activeConnection != nil || audioServer.activeUDPConnection != nil ? .green : .red)
                
                Text("Wi-Fi IP: \(audioServer.localIP)")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                if audioServer.isVisualizerEnabled {
                    // FFT Spectrum Visualizer
                    HStack(alignment: .center, spacing: 2) {
                        ForEach(0..<40, id: \.self) { index in
                            let value = CGFloat(audioServer.frequencyBuckets[index])
                            Capsule()
                                .fill(audioServer.volumeLevel < audioServer.noiseGateThreshold || audioServer.volumeLevel > audioServer.maxVolumeCutoff ? Color.gray : Color.green)
                                .frame(width: 4, height: max(5, 100 * value))
                                .animation(.linear(duration: 0.05), value: value)
                        }
                    }
                    .frame(height: 100)
                    .padding(.vertical, 10)
                }
                
                Toggle(isOn: $audioServer.isVisualizerEnabled) {
                    HStack {
                        Image(systemName: "waveform").foregroundColor(.green)
                        Text("Live Visualizer").font(.headline)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(15)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal, 30)
                
                Text("Live: \(String(format: "%.3f", audioServer.volumeLevel))  |  \(String(format: "%.1f", audioServer.currentDB)) dB")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(audioServer.volumeLevel < audioServer.noiseGateThreshold || audioServer.volumeLevel > audioServer.maxVolumeCutoff ? .red : .green)
                
                VStack(spacing: 15) {
                    // Digital Amplifier (Gain)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Image(systemName: "mic.fill").foregroundColor(.purple)
                            Text("Microphone Boost").font(.subheadline).bold()
                            Spacer()
                            Text("\(Int(audioServer.microphoneGain))x").font(.caption).bold().padding(.horizontal, 8).padding(.vertical, 4).background(Color.purple.opacity(0.2)).foregroundColor(.purple).cornerRadius(8)
                        }
                        HStack {
                            Button(action: { audioServer.microphoneGain = max(1.0, audioServer.microphoneGain - 1.0) }) {
                                Image(systemName: "minus").foregroundColor(.gray).font(.caption).padding(5)
                            }
                            Slider(value: $audioServer.microphoneGain, in: 1.0...10.0, step: 1.0).accentColor(.purple)
                            Button(action: { audioServer.microphoneGain = min(10.0, audioServer.microphoneGain + 1.0) }) {
                                Image(systemName: "plus").foregroundColor(.gray).font(.caption).padding(5)
                            }
                        }
                    }
                    .padding().background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(15).shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // Low Noise Gate Control
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Image(systemName: "speaker.slash.fill").foregroundColor(.blue)
                            Text("Noise Gate").font(.subheadline).bold()
                            Spacer()
                            Text(String(format: "%.3f", audioServer.noiseGateThreshold)).font(.caption).bold().padding(.horizontal, 8).padding(.vertical, 4).background(Color.blue.opacity(0.2)).foregroundColor(.blue).cornerRadius(8)
                        }
                        HStack {
                            Button(action: { audioServer.noiseGateThreshold = max(0.0, audioServer.noiseGateThreshold - 0.005) }) {
                                Image(systemName: "minus").foregroundColor(.gray).font(.caption).padding(5)
                            }
                            Slider(value: $audioServer.noiseGateThreshold, in: 0...0.1, step: 0.001).accentColor(.blue)
                            Button(action: { audioServer.noiseGateThreshold = min(0.1, audioServer.noiseGateThreshold + 0.005) }) {
                                Image(systemName: "plus").foregroundColor(.gray).font(.caption).padding(5)
                            }
                        }
                    }
                    .padding().background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(15).shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // Loud Noise Cutoff Control
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Image(systemName: "speaker.wave.3.fill").foregroundColor(.orange)
                            Text("Loudness Cutoff").font(.subheadline).bold()
                            Spacer()
                            Text(String(format: "%.3f", audioServer.maxVolumeCutoff)).font(.caption).bold().padding(.horizontal, 8).padding(.vertical, 4).background(Color.orange.opacity(0.2)).foregroundColor(.orange).cornerRadius(8)
                        }
                        HStack {
                            Button(action: { audioServer.maxVolumeCutoff = max(0.0, audioServer.maxVolumeCutoff - 0.05) }) {
                                Image(systemName: "minus").foregroundColor(.gray).font(.caption).padding(5)
                            }
                            Slider(value: $audioServer.maxVolumeCutoff, in: 0.0...1.0, step: 0.01).accentColor(.orange)
                            Button(action: { audioServer.maxVolumeCutoff = min(1.0, audioServer.maxVolumeCutoff + 0.05) }) {
                                Image(systemName: "plus").foregroundColor(.gray).font(.caption).padding(5)
                            }
                        }
                    }
                    .padding().background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(15).shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 10)
                
                // Start/Stop Button
                Button(action: {
                    audioServer.toggleServer()
                }) {
                    Text(audioServer.isRunning ? "Stop Streaming" : "Start Server")
                        .font(.title2)
                        .bold()
                        .frame(width: 200, height: 60)
                        .foregroundColor(.white)
                        .background(audioServer.isRunning ? Color.red : Color.blue)
                        .cornerRadius(30)
                }
                
                if #available(iOS 15.0, *) {
                    Button(action: {
                        if #available(iOS 16.4, *) {
                            AVCaptureDevice.showSystemUserInterface(.microphoneModes)
                        }
                    }) {
                        HStack {
                            Image(systemName: "waveform.and.mic")
                            Text("Voice Isolation")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(20)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                }
            }
            .padding(.top, 20)
        }
    }
}

// MARK: - Effects Tab
struct EffectsView: View {
    @ObservedObject var audioServer: AudioServer
    
    // 2-column grid
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(VoiceFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            audioServer.activeFilter = filter
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: iconForFilter(filter))
                                    .font(.system(size: 30))
                                Text(filter.rawValue)
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .foregroundColor(audioServer.activeFilter == filter ? .white : .primary)
                            .background(audioServer.activeFilter == filter ? Color.blue : Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Voice Filters")
        }
    }
    
    private func iconForFilter(_ filter: VoiceFilter) -> String {
        switch filter {
        case .normal: return "person.fill"
        case .chipmunk: return "hare.fill"
        case .monster: return "mustache.fill" // Or tortoise.fill
        case .robot: return "cpu"
        case .radio: return "antenna.radiowaves.left.and.right"
        case .cave: return "globe.americas.fill"
        case .alien: return "eye.trianglebadge.exclamationmark.fill"
        case .vader: return "star.fill"
        case .echo: return "waveform.path.ecg"
        case .megaphone: return "megaphone.fill"
        case .underwater: return "drop.fill"
        case .demon: return "flame.fill"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
