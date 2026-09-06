# uname for Windows (as a PowerShell command)
Emulates the GNU `uname` utility. On Linux and macOS, the script won't run, so the user can use the better native `uname` utility tailored for real UNIX systems.

On Windows, almost every field is derived live from CIM/WMI, the registry, and .NET, so no values that are found there are hardcoded.

# How to install into $PROFILE so you can call it anywhere
1. Download the PowerShell scripts or clone the repo to your device
2. Open a PowerShell in the same directory where the scripts are located
3. Run `./add_to_powershell_profile.ps1`
4. Run `. $PROFILE`
5. Now you've installed it! Just use `uname` with your desired flags to run it!

You can verify it's installed by running `uname --version`

# Fields and their Windows data sources
    
    -s | --kernel-name        Win32_OperatingSystem.OtherTypeDescription when set,
                              otherwise mapped from .OSType (18 -> "Windows_NT").
                              $Env:OS is used as a fast-path cross-check.
    -n | --nodename           [System.Net.Dns]::GetHostName(), which returns the
                              fully-qualified name when available, falling back to
                              $Env:COMPUTERNAME.
    -r | --kernel-release     Major.Minor.BuildNumber from Win32_OperatingSystem
                              plus the UBR (Update Build Revision) patch level read
                              from HKLM:\...\CurrentVersion, giving e.g. 10.0.26100.4061.
    -v | --kernel-version     Built from three live registry values:
                               * BuildLabEx (e.g. 26100.4061.amd64fre.ge_release...)
                                 or BuildLab as fallback
                               * DisplayVersion / ReleaseId (e.g. 24H2)
                              Formatted as "#<BuildNumber> SMP <UTC install timestamp>"
                              where the timestamp comes from Win32_OperatingSystem
                              .InstallDate (a real CIM datetime, never a placeholder).
    -m | --machine            [System.Runtime.InteropServices.RuntimeInformation]
                              ::OSArchitecture, mapped to conventional GNU/Linux tokens:
                               X64   -> x86_64   Arm64 -> aarch64
                               X86   -> i686     Arm   -> armv7l   S390x -> s390x
                              Falls back to $Env:PROCESSOR_ARCHITECTURE.
    -p | --processor          Win32_Processor.Name (CPU brand string, trimmed).
                              Falls back to $Env:PROCESSOR_IDENTIFIER, then -m value.
    -i | --hardware-platform  Same source as -m. Windows exposes no separate
                              hardware-platform ABI identifier.
    -o | --operating-system   Win32_OperatingSystem.Caption (marketing name),
                              e.g. "Microsoft Windows 11 Pro".

# Flag combinations
Flags may be combined in a single argument (-srv) or passed separately (-s -r -v). -a / --all is equivalent to -snrvmpio and outputs all fields in that order, space-separated on one line, identical to GNU uname.

# Parameters
`KernelName`: Print the kernel / OS family name. Flag: -s | --kernel-name

`NodeName`: Print the network node hostname. Flag: -n | --nodename

`KernelRelease`: Print the kernel release (Major.Minor.Build.UBR). Flag: -r | --kernel-release

`KernelVersion`: Print the kernel version (build-lab string + UTC install date). Flag: -v | --kernel-version

`Machine`: Print the machine hardware architecture token. Flag: -m | --machine

`Processor`: Print the processor brand string. Flag: -p | --processor

`HardwarePlatform`: Print the hardware platform (same source as -m on Windows). Flag: -i | --hardware-platform

`OperatingSystem`: Print the operating-system marketing name. Flag: -o | --operating-system

`All`: Print all fields in GNU order: s n r v m p i o. Flag: -a | --all

# Examples

Running the utility without flags
```terminal
PS C:\Users\example> uname
Windows_NT
```

Running the utility with the `-a` flag
```terminal
PS C:\Users\example> uname -a
Windows_NT PC 10.0.26100.4061 #26100 SMP sat jun  15 09:32:11 UTC 2024 x86_64 AMD Ryzen 5 5500 x86_64 Microsoft Windows 11 Pro
```

Running the utility with the `-s` and `-r` flags
```terminal
PS C:\Users\example> uname -sr
Windows_NT 10.0.26100.4061
```

Running the utility with the `--kernel-name` and `--machine` flags
```terminal
PS C:\Users\example> uname --kernel-name --machine
Windows_NT x86_64
```

Running the utility with the `-m`, `-r` and `-v` flags
```terminal
PS C:\Users\example> uname -mrv
10.0.26100.4061 #26100 SMP sat jun  15 09:32:11 UTC 2024 x86_64
```
