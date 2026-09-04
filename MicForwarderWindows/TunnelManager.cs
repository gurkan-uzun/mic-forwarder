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
                Logger.Log($"Starting tunnel with {iproxyPath} {localPort} {remotePort}");
                _iproxyProcess = Process.Start(startInfo);
                
                if (_iproxyProcess != null)
                {
                    _iproxyProcess.OutputDataReceived += (sender, args) => { if (!string.IsNullOrEmpty(args.Data)) Logger.Log($"[iproxy output] {args.Data}"); };
                    _iproxyProcess.ErrorDataReceived += (sender, args) => { if (!string.IsNullOrEmpty(args.Data)) Logger.Log($"[iproxy error] {args.Data}"); };
                    _iproxyProcess.BeginOutputReadLine();
                    _iproxyProcess.BeginErrorReadLine();
                }

                Logger.Log("iproxy tunnel started.");
            }
            catch (Exception ex)
            {
                Logger.Log($"Failed to start iproxy: {ex.Message}");
                throw;
            }
        }

        public void StopTunnel()
        {
            if (_iproxyProcess != null && !_iproxyProcess.HasExited)
            {
                Logger.Log("Stopping iproxy tunnel...");
                _iproxyProcess.Kill();
                _iproxyProcess.Dispose();
                _iproxyProcess = null;
                Logger.Log("iproxy tunnel stopped.");
            }
        }
    }
}
