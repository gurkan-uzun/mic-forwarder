using System;
using System.Net.Sockets;
using NAudio.Wave;
using System.Threading;
using System.Diagnostics;

namespace MicForwarderWindows
{
    public class AudioReceiver
    {
        private TcpClient? _client;
        private NetworkStream? _stream;
        private Thread? _receiveThread;
        private bool _isRunning;
        
        private WaveOutEvent? _waveOut;
        private BufferedWaveProvider? _waveProvider;
        
        public event Action<string>? OnStatusChanged;

        public void StartReceiving(int deviceNumber)
        {
            if (_isRunning) return;

            try
            {
                Logger.Log($"Connecting TCP Client to 127.0.0.1:12345...");
                _client = new TcpClient();
                _client.Connect("127.0.0.1", 12345);
                _stream = _client.GetStream();
                Logger.Log("TCP Client connected successfully.");

                // 48kHz, 16-bit, Mono (Must match iPhone's targetFormat)
                var waveFormat = new WaveFormat(48000, 16, 1);
                
                _waveProvider = new BufferedWaveProvider(waveFormat)
                {
                    BufferDuration = TimeSpan.FromSeconds(2),
                    DiscardOnBufferOverflow = true
                };

                _waveOut = new WaveOutEvent { DeviceNumber = deviceNumber };
                _waveOut.Init(_waveProvider);
                _waveOut.Play();

                _isRunning = true;
                _receiveThread = new Thread(ReceiveLoop) { IsBackground = true };
                _receiveThread.Start();
                
                OnStatusChanged?.Invoke("Connected and streaming...");
            }
            catch (Exception ex)
            {
                OnStatusChanged?.Invoke($"Connection failed: {ex.Message}");
                StopReceiving();
            }
        }

        private void ReceiveLoop()
        {
            byte[] buffer = new byte[4096];
            try
            {
                while (_isRunning && _stream != null)
                {
                    int bytesRead = _stream.Read(buffer, 0, buffer.Length);
                    if (bytesRead == 0)
                    {
                        OnStatusChanged?.Invoke("Connection closed by iPhone.");
                        break; // Connection closed
                    }
                    _waveProvider?.AddSamples(buffer, 0, bytesRead);
                }
            }
            catch (Exception ex)
            {
                if (_isRunning)
                {
                    OnStatusChanged?.Invoke($"Stream error: {ex.Message}");
                }
            }
            finally
            {
                StopReceiving();
            }
        }

        public void StopReceiving()
        {
            _isRunning = false;
            _stream?.Close();
            _client?.Close();
            
            _waveOut?.Stop();
            _waveOut?.Dispose();
            _waveOut = null;
            
            _waveProvider?.ClearBuffer();
            _waveProvider = null;
        }
    }
}
