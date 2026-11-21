using System;
using System.Diagnostics;
using System.IO;
using System.Text.RegularExpressions;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;

namespace SplitSpace {
    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct PROPERTYKEY {
        public Guid fmtid;
        public uint pid;
        public PROPERTYKEY(Guid g, uint p) { fmtid = g; pid = p; }
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct PROPVARIANT {
        [FieldOffset(0)] public ushort vt;
        [FieldOffset(8)] public IntPtr pwszVal;
    }

    [ComImport]
    [Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPropertyStore {
        [PreserveSig] int GetCount(out uint cProps);
        [PreserveSig] int GetAt(uint iProp, out PROPERTYKEY pkey);
        [PreserveSig] int GetValue(ref PROPERTYKEY key, out PROPVARIANT pv);
        [PreserveSig] int SetValue(ref PROPERTYKEY key, ref PROPVARIANT propvar);
        [PreserveSig] int Commit();
    }

    class Program {
        [DllImport("shell32.dll", SetLastError = true)]
        public static extern int SHGetPropertyStoreForWindow(IntPtr hwnd, ref Guid riid, [MarshalAs(UnmanagedType.Interface)] out IPropertyStore ppv);

        [DllImport("shell32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern int SetCurrentProcessExplicitAppUserModelID(string AppID);

        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);

        static void Main(string[] args) {
            string appName = args.Length > 0 ? args[0] : "Antigravity";
            string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string progFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);

            string appExe = null;
            string aumid = null;
            string processName = appName + ".exe";
            string defaultUserData = null;

            if (appName.Equals("Antigravity", StringComparison.OrdinalIgnoreCase)) {
                appExe = Path.Combine(localAppData, @"Programs\antigravity\Antigravity.exe");
                processName = "Antigravity.exe";
                aumid = null; // Standard Win32 app: pinned shortcut has no explicit AUMID. Do not override, to allow natural taskbar stacking.
                defaultUserData = Path.Combine(appData, "Antigravity");
            } else if (appName.Equals("Claude", StringComparison.OrdinalIgnoreCase)) {
                string alias1 = Path.Combine(localAppData, @"Microsoft\WindowsApps\Claude_pzs8sxrjxfjjc\claude-desktop.exe");
                string alias2 = Path.Combine(localAppData, @"Microsoft\WindowsApps\claude-desktop.exe");
                if (File.Exists(alias1)) appExe = alias1;
                else if (File.Exists(alias2)) appExe = alias2;
                else appExe = Path.Combine(localAppData, @"Programs\Claude\Claude.exe");
                processName = "Claude.exe";
                aumid = "Claude_pzs8sxrjxfjjc!Claude";
                defaultUserData = Path.Combine(localAppData, @"Claude-Data\claude_pzs8sxrjxfjjc");
                if (!Directory.Exists(defaultUserData)) defaultUserData = Path.Combine(localAppData, "Claude");
            } else if (appName.Equals("ChatGPT", StringComparison.OrdinalIgnoreCase)) {
                string alias1 = Path.Combine(localAppData, @"Microsoft\WindowsApps\OpenAI.Codex_2p2nqsd0c76g0\chatgpt-desktop.exe");
                string alias2 = Path.Combine(localAppData, @"Microsoft\WindowsApps\chatgpt-desktop.exe");
                if (File.Exists(alias1)) appExe = alias1;
                else if (File.Exists(alias2)) appExe = alias2;
                else appExe = Path.Combine(localAppData, @"Programs\ChatGPT\ChatGPT.exe");
                processName = "ChatGPT.exe";
                aumid = "OpenAI.Codex_2p2nqsd0c76g0!App";
                defaultUserData = Path.Combine(localAppData, @"Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Roaming\Codex");
                if (!Directory.Exists(defaultUserData)) defaultUserData = Path.Combine(appData, "Codex");
            } else if (appName.Equals("Windsurf", StringComparison.OrdinalIgnoreCase)) {
                appExe = Path.Combine(localAppData, @"Programs\Windsurf\Windsurf.exe");
                processName = "Windsurf.exe";
                defaultUserData = Path.Combine(appData, "Windsurf");
            }

            // Prefer provided executable if caller explicitly passed one, unless alias takes precedence for MSIX identity
            if (args.Length > 1 && !string.IsNullOrEmpty(args[1]) && File.Exists(args[1])) {
                if (appName.Equals("ChatGPT", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrEmpty(appExe) && File.Exists(appExe)) {
                    // Retain package execution alias for ChatGPT to preserve Store identity
                } else if (appName.Equals("Claude", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrEmpty(appExe) && File.Exists(appExe)) {
                    // Retain package execution alias for Claude to preserve Store identity
                } else {
                    appExe = args[1];
                }
            }

            if (string.IsNullOrEmpty(appExe) || !File.Exists(appExe)) return;

            // Set current process explicit AUMID
            if (!string.IsNullOrEmpty(aumid)) {
                try {
                    SetCurrentProcessExplicitAppUserModelID(aumid);
                } catch {}
            }

            string baseDir = Path.Combine(localAppData, "SplitSpace", "profiles", appName);
            Directory.CreateDirectory(baseDir);

            // Find currently running slots for this application
            var activeSlots = new HashSet<int>();

            try {
                using (var searcher = new System.Management.ManagementObjectSearcher(
                    "SELECT CommandLine FROM Win32_Process WHERE Name = '" + processName + "'")) {
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
            if (!string.IsNullOrEmpty(defaultUserData) && Directory.Exists(defaultUserData)) {
                string[] filesToSeed = new string[] {
                    "Local State",
                    "Preferences",
                    "app_storage.json",
                    "config.json",
                    "claude_desktop_config.json",
                    "browser-sidebar-local-servers.json"
                };
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
            string workingDir = Path.GetDirectoryName(appExe);
            if (!string.IsNullOrEmpty(workingDir) && Directory.Exists(workingDir)) {
                psi.WorkingDirectory = workingDir;
            }
            psi.UseShellExecute = true;

            Process proc = Process.Start(psi);

            // Assign window AppUserModelID to ensure taskbar stacking under pinned icon
            if (!string.IsNullOrEmpty(aumid)) {
                Guid iid = new Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99");
                PROPERTYKEY pkeyAumid = new PROPERTYKEY(new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), 5);

                bool assigned = false;
                for (int i = 0; i < 30; i++) {
                    Thread.Sleep(200);
                    try {
                        var pids = new HashSet<int>();
                        if (proc != null && !proc.HasExited) {
                            pids.Add(proc.Id);
                        }

                        // Search by processName and command-line containing this slot
                        using (var searcher = new System.Management.ManagementObjectSearcher(
                            "SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name = '" + processName + "'")) {
                            foreach (var obj in searcher.Get()) {
                                string cmd = obj["CommandLine"] as string;
                                if (!string.IsNullOrEmpty(cmd) && cmd.IndexOf("slot-" + selectedSlot, StringComparison.OrdinalIgnoreCase) >= 0) {
                                    pids.Add(Convert.ToInt32(obj["ProcessId"]));
                                }
                            }
                        }

                        // Also include child processes of all collected PIDs
                        var basePids = new List<int>(pids);
                        foreach (int p in basePids) {
                            try {
                                using (var searcher = new System.Management.ManagementObjectSearcher(
                                    "SELECT ProcessId FROM Win32_Process WHERE ParentProcessId = " + p)) {
                                    foreach (var obj in searcher.Get()) {
                                        pids.Add(Convert.ToInt32(obj["ProcessId"]));
                                    }
                                }
                            } catch {}
                        }

                        if (pids.Count > 0) {
                            EnumWindows((hwnd, lParam) => {
                                uint pid;
                                GetWindowThreadProcessId(hwnd, out pid);
                                if (pids.Contains((int)pid) && IsWindowVisible(hwnd)) {
                                    IPropertyStore store;
                                    if (SHGetPropertyStoreForWindow(hwnd, ref iid, out store) == 0 && store != null) {
                                        PROPVARIANT pv = new PROPVARIANT();
                                        pv.vt = 31; // VT_LPWSTR
                                        pv.pwszVal = Marshal.StringToCoTaskMemUni(aumid);
                                        store.SetValue(ref pkeyAumid, ref pv);
                                        store.Commit();
                                        Marshal.FreeCoTaskMem(pv.pwszVal);
                                        Marshal.ReleaseComObject(store);
                                        assigned = true;
                                    }
                                }
                                return true;
                            }, IntPtr.Zero);
                        }

                        if (assigned) {
                            break;
                        }
                    } catch {}
                }
            }
        }
    }
}
