using System;
using System.IO;

namespace MicForwarderWindows
{
    public static class Logger
    {
        private static readonly string LogFilePath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "mic-forwarder.log");

        public static void Log(string message)
        {
            try
            {
                string logEntry = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff}] {message}";
                System.Diagnostics.Debug.WriteLine(logEntry); // Still output to debugger
                File.AppendAllText(LogFilePath, logEntry + Environment.NewLine);
            }
            catch
            {
                // Ignore logging errors so we don't crash the app
            }
        }
    }
}
