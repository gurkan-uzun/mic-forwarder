using System;
using System.Linq;
using System.Windows;
using NAudio.Wave;

namespace MicForwarderWindows
{
    public partial class MainWindow : Window
    {
        private TunnelManager _tunnelManager;
        private AudioReceiver _audioReceiver;
        private bool _isConnected = false;

        public MainWindow()
        {
            InitializeComponent();
            _tunnelManager = new TunnelManager();
            _audioReceiver = new AudioReceiver();
            _audioReceiver.OnStatusChanged += UpdateStatus;
            
            LoadAudioDevices();
        }

        private void LoadAudioDevices()
        {
            DeviceComboBox.Items.Clear();
            for (int i = 0; i < WaveOut.DeviceCount; i++)
            {
                var capabilities = WaveOut.GetCapabilities(i);
                DeviceComboBox.Items.Add(new { Name = capabilities.ProductName, Index = i });
            }
            
            if (DeviceComboBox.Items.Count > 0)
                DeviceComboBox.SelectedIndex = 0;
        }

        private void ConnectButton_Click(object sender, RoutedEventArgs e)
        {
            if (_isConnected)
            {
                Disconnect();
            }
            else
            {
                if (DeviceComboBox.SelectedItem == null)
                {
                    MessageBox.Show("Please select an output device.");
                    return;
                }

                dynamic selectedDevice = DeviceComboBox.SelectedItem;
                int deviceIndex = selectedDevice.Index;

                Connect(deviceIndex);
            }
        }

        private async void Connect(int deviceIndex)
        {
            try
            {
                UpdateStatus("Starting USB Tunnel...");
                _tunnelManager.StartTunnel(12345, 12345);

                // Give iproxy a second to start up and bind the local port
                await System.Threading.Tasks.Task.Delay(1000);

                UpdateStatus("Connecting to iPhone...");
                _audioReceiver.StartReceiving(deviceIndex);
                
                _isConnected = true;
                ConnectButton.Content = "Disconnect";
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Failed to connect: {ex.Message}");
                Disconnect();
            }
        }

        private void Disconnect()
        {
            _audioReceiver.StopReceiving();
            _tunnelManager.StopTunnel();
            
            _isConnected = false;
            ConnectButton.Content = "Connect to iPhone";
            UpdateStatus("Disconnected.");
        }

        private void UpdateStatus(string status)
        {
            Logger.Log($"[Status] {status}");
            Dispatcher.Invoke(() =>
            {
                StatusText.Text = status;
                
                if (status.Contains("error") || status.Contains("failed") || status.Contains("closed"))
                {
                    StatusText.Foreground = System.Windows.Media.Brushes.Red;
                    if (_isConnected) Disconnect(); // auto disconnect on error
                }
                else if (status.Contains("streaming"))
                {
                    StatusText.Foreground = System.Windows.Media.Brushes.Green;
                }
                else
                {
                    StatusText.Foreground = System.Windows.Media.Brushes.Gray;
                }
            });
        }

        private void Window_Closing(object sender, System.ComponentModel.CancelEventArgs e)
        {
            Disconnect();
        }
    }
}
