using System;
using System.Diagnostics;
using System.IO;

namespace MicForwarderWindows
{
    public class TunnelManager
    {
        private Process? _iproxyProcess;

        public void StartTunnel(int localPort = 12345, int remotePort = 12345)
        {
            StopTunnel();

            string architecture = Environment.Is64BitOperatingSystem ? "x64" : "x86";
            string iproxyPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "third_party", architecture, "iproxy.exe");

            var startInfo = new ProcessStartInfo
            {
                FileName = iproxyPath,
                Arguments = $"{localPort} {remotePort}",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };

            try
            {
                _iproxyProcess = Process.Start(startInfo);
                Debug.WriteLine("iproxy tunnel started.");
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Failed to start iproxy: {ex.Message}. Make sure iproxy.exe is available.");
                throw;
            }
        }

        public void StopTunnel()
        {
            if (_iproxyProcess != null && !_iproxyProcess.HasExited)
            {
                _iproxyProcess.Kill();
                _iproxyProcess.Dispose();
                _iproxyProcess = null;
                Debug.WriteLine("iproxy tunnel stopped.");
            }
        }
    }
}
