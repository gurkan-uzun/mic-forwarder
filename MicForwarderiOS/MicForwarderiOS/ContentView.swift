//
//  ContentView.swift
//  MicForwarderiOS
//
//  Created by Gürkan uzun on 4.09.2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var audioServer = AudioServer()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Mic Forwarder")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 10)
                
                // Connection Status
                Text(audioServer.connectionStatus)
                    .foregroundColor(audioServer.connectionStatus.contains("Connected") ? .green : .secondary)
                    .font(.headline)
                
                // Microphone Volume Indicator
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 40, height: 150)
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green)
                        .frame(width: 40, height: 150 * CGFloat(min(audioServer.volumeLevel * 5, 1.0)))
                        .animation(.linear(duration: 0.1), value: audioServer.volumeLevel)
                }
                .padding(.vertical, 10)
                
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
                        Slider(value: $audioServer.microphoneGain, in: 1.0...20.0, step: 1.0)
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
                
                Text("Port: 12345 (TCP)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
            }
            .padding(.bottom, 20)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
