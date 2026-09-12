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
        
        private UdpClient? _udpClient;
        private UdpClient? _metricsClient;
        
        private Thread? _receiveThread;
        private Thread? _metricsThread;
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
                _client.NoDelay = true;
                _client.Connect("127.0.0.1", 12345);
                _stream = _client.GetStream();
                Logger.Log("TCP Client connected successfully.");

                StartAudioAndMetrics(deviceNumber, "127.0.0.1");
                
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

        public void StartReceivingUDP(int deviceNumber, string ipAddress, int port)
        {
            if (_isRunning) return;

            try
            {
                Logger.Log($"Starting UDP Client to connect to {ipAddress}:{port}...");
                _udpClient = new UdpClient();
                _udpClient.Connect(ipAddress, port);
                
                byte[] handshake = System.Text.Encoding.ASCII.GetBytes("HELLO");
                _udpClient.Send(handshake, handshake.Length);

                StartAudioAndMetrics(deviceNumber, ipAddress);

                _receiveThread = new Thread(ReceiveUDPLoop) { IsBackground = true };
                _receiveThread.Start();
                
                OnStatusChanged?.Invoke("Connected via UDP and streaming...");
            }
            catch (Exception ex)
            {
                OnStatusChanged?.Invoke($"UDP Connection failed: {ex.Message}");
                StopReceiving();
            }
        }

        private void StartAudioAndMetrics(int deviceNumber, string ipAddress)
        {
            var waveFormat = new WaveFormat(48000, 16, 1);
            _waveProvider = new BufferedWaveProvider(waveFormat)
            {
                BufferDuration = TimeSpan.FromSeconds(2),
                DiscardOnBufferOverflow = true
            };

            _waveOut = new WaveOutEvent 
            { 
                DeviceNumber = deviceNumber,
                DesiredLatency = 60,
                NumberOfBuffers = 2
            };
            _waveOut.Init(_waveProvider);
            _waveOut.Play();

            _isRunning = true;

            try 
            {
                _metricsClient = new UdpClient();
                _metricsClient.Connect(ipAddress, 12346);
                byte[] handshake = System.Text.Encoding.ASCII.GetBytes("METRICS");
                _metricsClient.Send(handshake, handshake.Length);

                _metricsThread = new Thread(MetricsLoop) { IsBackground = true };
                _metricsThread.Start();
            } 
            catch (Exception ex) 
            {
                Logger.Log($"Failed to start metrics client: {ex.Message}");
            }
        }

        private void MetricsLoop()
        {
            try
            {
                System.Net.IPEndPoint remoteEP = new System.Net.IPEndPoint(System.Net.IPAddress.Any, 0);
                while (_isRunning && _metricsClient != null)
                {
                    byte[] data = _metricsClient.Receive(ref remoteEP);
                    // Echo the exact packet back to the iPhone so it can calculate Ping
                    _metricsClient.Send(data, data.Length);
                }
            }
            catch (Exception)
            {
                // Normal on disconnect
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
                        break;
                    }
                    
                    if (_waveProvider != null && _waveProvider.BufferedDuration.TotalMilliseconds > 90)
                    {
                        _waveProvider.ClearBuffer();
                    }

                    _waveProvider?.AddSamples(buffer, 0, bytesRead);
                }
            }
            catch (Exception ex)
            {
                if (_isRunning) OnStatusChanged?.Invoke($"Stream error: {ex.Message}");
            }
            finally
            {
                StopReceiving();
            }
        }

        private void ReceiveUDPLoop()
        {
            try
            {
                System.Net.IPEndPoint remoteEP = new System.Net.IPEndPoint(System.Net.IPAddress.Any, 0);
                while (_isRunning && _udpClient != null)
                {
                    byte[] data = _udpClient.Receive(ref remoteEP);
                    
                    if (_waveProvider != null && _waveProvider.BufferedDuration.TotalMilliseconds > 90)
                    {
                        _waveProvider.ClearBuffer();
                    }

                    _waveProvider?.AddSamples(data, 0, data.Length);
                }
            }
            catch (Exception ex)
            {
                if (_isRunning) OnStatusChanged?.Invoke($"UDP Stream error: {ex.Message}");
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
            _udpClient?.Close();
            _metricsClient?.Close();
            
            _waveOut?.Stop();
            _waveOut?.Dispose();
            _waveOut = null;
            
            _waveProvider?.ClearBuffer();
            _waveProvider = null;
        }
    }
}
