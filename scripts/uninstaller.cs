using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

class MiLuUninstaller
{
    [STAThread]
    static void Main()
    {
        var result = MessageBox.Show(
            "确定要卸载 MiLu Desktop 吗？\n\n" +
            "这将删除程序文件。\n" +
            "用户数据（%LOCALAPPDATA%\\MiLu Desktop）不会被删除。",
            "MiLu Desktop - 卸载",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Question);

        if (result != DialogResult.Yes)
            return;

        string baseDir = AppDomain.CurrentDomain.BaseDirectory;
        string appDir = Path.Combine(baseDir, "app");

        // Kill running MiLu processes
        foreach (var p in Process.GetProcessesByName("MiLu"))
        {
            try { p.Kill(); } catch { }
        }
        System.Threading.Thread.Sleep(2000);

        // Remove app directory
        if (Directory.Exists(appDir))
        {
            try { Directory.Delete(appDir, true); } catch { }
        }

        // Remove launcher
        string launcher = Path.Combine(baseDir, "MiLu.exe");
        if (File.Exists(launcher))
        {
            try { File.Delete(launcher); } catch { }
        }

        // Remove shortcuts
        foreach (var f in new[] { "MiLu.lnk", "MiLu.cmd", "uninstallerMiLu.cmd", "uninstallerMiLu.lnk" })
        {
            string fp = Path.Combine(baseDir, f);
            if (File.Exists(fp)) try { File.Delete(fp); } catch { }
        }

        MessageBox.Show(
            "卸载完成！\n\n" +
            "如需删除用户数据，请手动删除：\n" +
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData) +
            "\\MiLu Desktop",
            "MiLu Desktop - 卸载",
            MessageBoxButtons.OK,
            MessageBoxIcon.Information);

        // Self-delete via cmd
        string self = System.Reflection.Assembly.GetExecutingAssembly().Location;
        var psi = new ProcessStartInfo
        {
            FileName = "cmd.exe",
            Arguments = "/c timeout /t 2 /nobreak >nul & del \"" + self + "\"",
            WindowStyle = ProcessWindowStyle.Hidden,
            CreateNoWindow = true
        };
        Process.Start(psi);
    }
}
