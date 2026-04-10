using System;
using System.Diagnostics;
using System.IO;

class MiLuLauncher
{
    static void Main()
    {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string exe = Path.Combine(dir, "app", "win-unpacked", "MiLu.exe");
        if (!File.Exists(exe))
        {
            Console.Error.WriteLine("MiLu.exe not found: " + exe);
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
