//
//  ContentView.swift
//  MicForwarderiOS
//
//  Created by Gürkan uzun on 4.09.2026.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var audioServer = AudioServer()
    @State private var dragStartMaxVolume: Float? = nil
    @State private var dragStartNoiseGate: Float? = nil
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Mic Forwarder")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 10)
                
                // Connection Status
                Text(audioServer.connectionStatus)
                    .foregroundColor(audioServer.connectionStatus.contains("Connected") ? .green : .secondary)
                    .font(.headline)
                
                Text("Wi-Fi IP: \(audioServer.localIP)")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                if audioServer.isVisualizerEnabled {
                    // FFT Spectrum Visualizer with Drag Handles
                    ZStack(alignment: .top) {
                        HStack(alignment: .center, spacing: 2) {
                            ForEach(0..<40, id: \.self) { index in
                                let value = CGFloat(audioServer.frequencyBuckets[index])
                                Capsule()
                                    .fill(audioServer.volumeLevel < audioServer.noiseGateThreshold || audioServer.volumeLevel > audioServer.maxVolumeCutoff ? Color.gray : Color.green)
                                    .frame(width: 4, height: max(5, 100 * value))
                                    .animation(.linear(duration: 0.05), value: value)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: 100)
                        
                        // Max Volume Cutoff Draggable Line (Orange)
                        let yCutoff = 100.0 - (CGFloat(audioServer.maxVolumeCutoff) * 100.0)
                        ZStack {
                            Color.white.opacity(0.001) // Invisible hit area
                            Rectangle().fill(Color.orange).frame(height: 2)
                        }
                        .frame(height: 30)
                        .offset(y: yCutoff - 15)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if dragStartMaxVolume == nil { dragStartMaxVolume = audioServer.maxVolumeCutoff }
                                    let delta = -(value.translation.height / 100.0)
                                    let newVal = CGFloat(dragStartMaxVolume!) + delta
                                    audioServer.maxVolumeCutoff = Float(min(max(newVal, CGFloat(audioServer.noiseGateThreshold + 0.05)), 1.0))
                                }
                                .onEnded { _ in
                                    dragStartMaxVolume = nil
                                }
                        )
                        
                        // Noise Gate Draggable Line (Blue)
                        let yNoise = 100.0 - (CGFloat(audioServer.noiseGateThreshold) * 100.0)
                        ZStack {
                            Color.white.opacity(0.001) // Invisible hit area
                            Rectangle().fill(Color.blue).frame(height: 2)
                        }
                        .frame(height: 30)
                        .offset(y: yNoise - 15)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if dragStartNoiseGate == nil { dragStartNoiseGate = audioServer.noiseGateThreshold }
                                    let delta = -(value.translation.height / 100.0)
                                    let newVal = CGFloat(dragStartNoiseGate!) + delta
                                    audioServer.noiseGateThreshold = Float(max(min(newVal, CGFloat(audioServer.maxVolumeCutoff - 0.05)), 0.0))
                                }
                                .onEnded { _ in
                                    dragStartNoiseGate = nil
                                }
                        )
                    }
                    .frame(height: 100)
                    .padding(.vertical, 10)
                    .clipped() // Prevent lines from extending outside the visualizer box
                }
                
                Toggle("Show Visualizer (Uses CPU)", isOn: $audioServer.isVisualizerEnabled)
                    .font(.caption)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 10)
                
                Text("Live: \(String(format: "%.3f", audioServer.volumeLevel))  |  \(String(format: "%.1f", audioServer.currentDB)) dB")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(audioServer.volumeLevel < audioServer.noiseGateThreshold || audioServer.volumeLevel > audioServer.maxVolumeCutoff ? .red : .green)
                
                VStack(spacing: 15) {
                    // Digital Amplifier (Gain)
                    VStack(spacing: 5) {
                        Text("Microphone Boost: \(Int(audioServer.microphoneGain))x")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $audioServer.microphoneGain, in: 1.0...10.0, step: 1.0)
                            .accentColor(.purple)
                    }
                    
                    // Low Noise Gate Control
                    VStack(spacing: 5) {
                        Text("Mute quiet sounds below: \(String(format: "%.3f", audioServer.noiseGateThreshold))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $audioServer.noiseGateThreshold, in: 0...0.1, step: 0.001)
                            .accentColor(.blue)
                    }
                    
                    // Loud Noise Cutoff Control
                    VStack(spacing: 5) {
                        Text("Mute loud sounds above: \(String(format: "%.3f", audioServer.maxVolumeCutoff))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $audioServer.maxVolumeCutoff, in: 0.0...1.0, step: 0.01)
                            .accentColor(.orange)
                    }
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
                        // Open the iOS System panel for Voice Isolation
                        if #available(iOS 16.4, *) {
                            AVCaptureDevice.showSystemUserInterface(.microphoneModes)
                        }
                    }) {
                        Text("Enable Voice Isolation (System)")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(.top, 5)
                    }
                }
                
                Text("Port: 12345 (TCP & UDP)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
            }
        }
    }

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
