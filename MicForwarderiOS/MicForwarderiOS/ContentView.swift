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
        VStack(spacing: 30) {
            Text("Mic Forwarder")
                .font(.largeTitle)
                .bold()
            
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
            .padding()
            
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
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
