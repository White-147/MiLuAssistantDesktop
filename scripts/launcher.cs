using System;
using System.Diagnostics;
using System.IO;

class MiLuAssistantDesktopLauncher
{
    static void Main()
    {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string exe = Path.Combine(dir, "app", "win-unpacked", "MiLuAssistantDesktop.exe");
        if (!File.Exists(exe))
        {
            Console.Error.WriteLine("MiLuAssistantDesktop.exe not found: " + exe);
            Environment.Exit(1);
        }
        var psi = new ProcessStartInfo
        {
            FileName = exe,
            WorkingDirectory = Path.GetDirectoryName(exe),
            UseShellExecute = true
        };
        Process.Start(psi);
    }
}
