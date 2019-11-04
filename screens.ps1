$MethodDefinition = @'
using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Text;
using System.Collections;
using System.Collections.Generic;
public class CountdownLatch {
  private int m_remain;
  private EventWaitHandle m_event;

  public CountdownLatch(int count) {
      m_remain = count;
      m_event = new ManualResetEvent(false);
  }

  public void Signal() {
      // The last thread to signal also sets the event.
      if (Interlocked.Decrement(ref m_remain) == 0)
          m_event.Set();
  }

  public void Wait() {
      m_event.WaitOne();
  }
}
public class User32Methods {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct PHYSICAL_MONITOR
  {
      public IntPtr hPhysicalMonitor;

      [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string szPhysicalMonitorDescription;
  }

  [DllImport("Dxva2.dll", EntryPoint = "GetNumberOfPhysicalMonitorsFromHMONITOR")]
  public static extern bool GetNumberOfPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, ref UInt32 physicalMonitorCount);

  [DllImport("dxva2.dll", EntryPoint = "GetPhysicalMonitorsFromHMONITOR")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool GetPhysicalMonitorsFromHMONITOR(
      IntPtr hMonitor, uint dwPhysicalMonitorArraySize, [Out] PHYSICAL_MONITOR[] pPhysicalMonitorArray);

  [DllImport("dxva2.dll", EntryPoint = "GetCapabilitiesStringLength")]
  public static extern bool GetCapabilitiesStringLength(IntPtr hMonitor, ref UInt32 len);

  [DllImport("dxva2.dll", EntryPoint = "CapabilitiesRequestAndCapabilitiesReply")]
  public static extern bool CapabilitiesRequestAndCapabilitiesReply(IntPtr hMonitor, StringBuilder caps, UInt32 len);

  [DllImport("dxva2.dll", EntryPoint = "SetVCPFeature")]
  public static extern bool SetVCPFeature(IntPtr hMonitor, byte bVCPCode, UInt32 dwNewValue);
  
  [DllImport("dxva2.dll", EntryPoint = "SaveCurrentSettings")]
  public static extern bool SaveCurrentSettings(IntPtr hMonitor);

  [DllImport("user32.dll", EntryPoint = "EnumDisplayMonitors")]
  public static extern bool EnumDisplayMonitors(IntPtr hMonitor, IntPtr lprcClip, MonitorEnumDelegate lpfnEnum, IntPtr dwData);
  
  
  public delegate bool MonitorEnumDelegate( IntPtr hMonitor,IntPtr hdcMonitor,ref IntPtr lprcMonitor, IntPtr dwData );

  private static CountdownLatch latch = new CountdownLatch(3);

  public static bool HandleDelegate(IntPtr hMonitor,IntPtr hdcMonitor,ref IntPtr lprcMonitor, IntPtr dwData) {
    UInt32 count = 0;
    GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor, ref count);
    PHYSICAL_MONITOR[] monitors = new PHYSICAL_MONITOR[count];
    GetPhysicalMonitorsFromHMONITOR(hMonitor, count, monitors);
    SetVCPFeature(monitors[0].hPhysicalMonitor, 0x60, 0x0f);
    SaveCurrentSettings(monitors[0].hPhysicalMonitor);
    latch.Signal();
    return true;
  }
  public static bool InfoDelegate(IntPtr hMonitor,IntPtr hdcMonitor,ref IntPtr lprcMonitor, IntPtr dwData) {
    UInt32 count = 0;
    GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor, ref count);
    PHYSICAL_MONITOR[] monitors = new PHYSICAL_MONITOR[count];
    GetPhysicalMonitorsFromHMONITOR(hMonitor, count, monitors);
    System.Console.WriteLine(monitors[0].szPhysicalMonitorDescription);
    GetCapabilitiesStringLength(monitors[0].hPhysicalMonitor, ref count);
    System.Console.WriteLine(count);
    StringBuilder caps = new StringBuilder((int)count);
    CapabilitiesRequestAndCapabilitiesReply(monitors[0].hPhysicalMonitor, caps, count);
    System.Console.WriteLine(caps);
    latch.Signal();
    return true;
  }
  public static void CallDisplayMonitors() 
  {
    EnumDisplayMonitors(IntPtr.Zero,IntPtr.Zero,HandleDelegate,IntPtr.Zero);
    latch.Wait();
  }
}
'@
$typeFunc = Add-Type -TypeDefinition $MethodDefinition
Get-Content -Path "synergy.log" -Tail 1 -Wait | ForEach-Object {
  if ($_ -like "*leaving*") {
    [User32Methods]::CallDisplayMonitors();
  }
}