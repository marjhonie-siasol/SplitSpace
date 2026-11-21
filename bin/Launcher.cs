using System;
using System.Diagnostics;
using System.IO;
using System.Text.RegularExpressions;
using System.Collections.Generic;

namespace SplitSpace {
    class Program {
        static void Main(string[] args) {
            string appName = args.Length > 0 ? args[0] : "Antigravity";
            string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string progFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);

            string appExe = null;
            if (args.Length > 1 && !string.IsNullOrEmpty(args[1]) && File.Exists(args[1])) {
                appExe = args[1];
            } else {
                if (appName.Equals("Antigravity", StringComparison.OrdinalIgnoreCase)) {
                    appExe = Path.Combine(localAppData, @"Programs\antigravity\Antigravity.exe");
                } else if (appName.Equals("Cursor", StringComparison.OrdinalIgnoreCase)) {
                    appExe = Path.Combine(progFiles, @"cursor\Cursor.exe");
                    if (!File.Exists(appExe)) appExe = Path.Combine(localAppData, @"Programs\cursor\Cursor.exe");
                } else if (appName.Equals("Claude", StringComparison.OrdinalIgnoreCase)) {
                    appExe = Path.Combine(localAppData, @"Programs\Claude\Claude.exe");
                } else if (appName.Equals("ChatGPT", StringComparison.OrdinalIgnoreCase)) {
                    appExe = Path.Combine(localAppData, @"Programs\ChatGPT\ChatGPT.exe");
                } else if (appName.Equals("Windsurf", StringComparison.OrdinalIgnoreCase)) {
                    appExe = Path.Combine(localAppData, @"Programs\Windsurf\Windsurf.exe");
                }
            }

            if (string.IsNullOrEmpty(appExe) || !File.Exists(appExe)) return;

            string baseDir = Path.Combine(localAppData, "SplitSpace", "profiles", appName);
            Directory.CreateDirectory(baseDir);

            // Find currently running slots for this application
            var activeSlots = new HashSet<int>();
            string exeName = Path.GetFileName(appExe);

            try {
                using (var searcher = new System.Management.ManagementObjectSearcher(
                    "SELECT CommandLine FROM Win32_Process WHERE Name = '" + exeName + "'")) {
                    foreach (var obj in searcher.Get()) {
                        string cmd = obj["CommandLine"] as string;
                        if (!string.IsNullOrEmpty(cmd)) {
                            var match = Regex.Match(cmd, @"slot-(\d+)");
                            if (match.Success) {
                                activeSlots.Add(int.Parse(match.Groups[1].Value));
                            }
                        }
                    }
                }
            } catch {
                // Fallback: check lockfiles
                for (int s = 1; s <= 20; s++) {
                    string sDir = Path.Combine(baseDir, "slot-" + s);
                    string lf = Path.Combine(sDir, "lockfile");
                    if (File.Exists(lf)) {
                        try {
                            using (var fs = File.Open(lf, FileMode.Open, FileAccess.ReadWrite, FileShare.None)) {}
                        } catch {
                            activeSlots.Add(s);
                        }
                    }
                }
            }

            // Find lowest available slot
            int selectedSlot = 1;
            for (int s = 1; s <= 20; s++) {
                if (!activeSlots.Contains(s)) {
                    selectedSlot = s;
                    break;
                }
            }

            string chosenSlotDir = Path.Combine(baseDir, "slot-" + selectedSlot);
            Directory.CreateDirectory(chosenSlotDir);

            // Seed user data if slot is fresh
            string defaultUserData = Path.Combine(appData, appName);
            if (!Directory.Exists(defaultUserData)) {
                defaultUserData = Path.Combine(localAppData, appName);
            }
            if (Directory.Exists(defaultUserData)) {
                string[] filesToSeed = new string[] { "Local State", "Preferences", "app_storage.json" };
                foreach (string f in filesToSeed) {
                    string src = Path.Combine(defaultUserData, f);
                    string dst = Path.Combine(chosenSlotDir, f);
                    if (File.Exists(src) && !File.Exists(dst)) {
                        try { File.Copy(src, dst, false); } catch {}
                    }
                }
            }

            // Launch isolated floating instance
            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = appExe;
            psi.Arguments = "--user-data-dir=\"" + chosenSlotDir + "\"";
            psi.WorkingDirectory = Path.GetDirectoryName(appExe);
            psi.UseShellExecute = true;
            Process.Start(psi);
        }
    }
}
