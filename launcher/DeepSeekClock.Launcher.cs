using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

namespace DeepSeekClock
{
    internal static class Launcher
    {
        [STAThread]
        private static void Main()
        {
            try
            {
                string appDir = AppDomain.CurrentDomain.BaseDirectory;
                string scriptPath = Path.Combine(appDir, "DeepSeekClock.ps1");
                if (!File.Exists(scriptPath))
                {
                    MessageBox.Show(
                        "找不到 DeepSeekClock.ps1。请保持挂件文件夹结构完整。",
                        "DeepSeek 时段挂件",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error);
                    return;
                }

                string windowsDir = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
                string powerShell = Path.Combine(windowsDir, "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
                if (!File.Exists(powerShell))
                {
                    MessageBox.Show(
                        "找不到 Windows PowerShell 5.1，无法启动挂件。",
                        "DeepSeek 时段挂件",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error);
                    return;
                }

                ProcessStartInfo startInfo = new ProcessStartInfo();
                startInfo.FileName = powerShell;
                startInfo.Arguments = "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + scriptPath + "\"";
                startInfo.WorkingDirectory = appDir;
                startInfo.UseShellExecute = false;
                startInfo.CreateNoWindow = true;
                startInfo.WindowStyle = ProcessWindowStyle.Hidden;
                Process.Start(startInfo);
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "启动挂件失败：" + ex.Message,
                    "DeepSeek 时段挂件",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
            }
        }
    }
}
