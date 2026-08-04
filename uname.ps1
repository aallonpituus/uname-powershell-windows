function uname {
        [CmdletBinding()]
    param (
        [Alias('s')] [switch]$KernelName,
        [Alias('n')] [switch]$NodeName,
        [Alias('r')] [switch]$KernelRelease,
        [Alias('v')] [switch]$KernelVersion,
        [Alias('m')] [switch]$Machine,
        [Alias('p')] [switch]$Processor,
        [Alias('i')] [switch]$HardwarePlatform,
        [Alias('o')] [switch]$OperatingSystem,
        [Alias('a')] [switch]$All,
        [switch]$Help,
        [switch]$Version,
        [Parameter(ValueFromRemainingArguments = $true)] [string[]]$RawArgs
    )

    #### Check: --help and --version ####

    $showHelp    = $Help    -or ($RawArgs -contains '--help')
    $showVersion = $Version -or ($RawArgs -contains '--version')

    if ($showHelp) {
        @'
Usage: uname [OPTION]...
Print certain system information.  With no OPTION, same as -s.

  -a, --all                print all information, in the following order,
                             except omit -p and -i if unknown:
  -s, --kernel-name        print the kernel name
  -n, --nodename           print the network node hostname
  -r, --kernel-release     print the kernel release
  -v, --kernel-version     print the kernel version
  -m, --machine            print the machine hardware name
  -p, --processor          print the processor type (non-portable)
  -i, --hardware-platform  print the hardware platform (non-portable)
  -o, --operating-system   print the operating system
      --help     display this help and exit
      --version  output version information and exit
'@
        return
    }

    if ($showVersion) {
        @"
uname (Windows Emulation) 1.0.0
Copyright (C) 2026 aallon-pituus 
This is free software: you are free to change and redistribute it.
This software is licensed under the terms of the MIT license.
There is NO WARRANTY, to the extent permitted by law.

Source: github.com/aallon-pituus/uname-powershell-windows
"@
        return
    }

    #### Ensure this function is running on Windows ####
  
    if ($IsLinux -or $IsMacOS -or ($null -ne $IsWindows -and -not $IsWindows)) {
        Write-Error "This PowerShell uname implementation is intended for Windows only. Use the native system binary on Linux/macOS."
        return
    }

    #### Parse requested options into POSIX order map (s n r v m p i o) ####

    $want = [ordered]@{
        s = $false
        n = $false
        r = $false
        v = $false
        m = $false
        p = $false
        i = $false
        o = $false
    }

    $enableAll = {
        foreach ($k in @('s','n','r','v','m','p','i','o')) { $want[$k] = $true }
    }

    # Bind named parameters
    if ($All)              { & $enableAll }
    if ($KernelName)       { $want.s = $true }
    if ($NodeName)         { $want.n = $true }
    if ($KernelRelease)    { $want.r = $true }
    if ($KernelVersion)    { $want.v = $true }
    if ($Machine)          { $want.m = $true }
    if ($Processor)        { $want.p = $true }
    if ($HardwarePlatform) { $want.i = $true }
    if ($OperatingSystem)  { $want.o = $true }

    # Parse remaining positional string arguments (e.g. -srv, --all)
    if ($RawArgs) {
        foreach ($token in $RawArgs) {
            switch -Regex ($token) {
                '^--all$'               { & $enableAll; break }
                '^--kernel-name$'       { $want.s = $true; break }
                '^--nodename$'          { $want.n = $true; break }
                '^--kernel-release$'    { $want.r = $true; break }
                '^--kernel-version$'    { $want.v = $true; break }
                '^--machine$'           { $want.m = $true; break }
                '^--processor$'         { $want.p = $true; break }
                '^--hardware-platform$' { $want.i = $true; break }
                '^--operating-system$'  { $want.o = $true; break }
                '^--help$'              { break } 
                '^--version$'           { break } 
                '^-[snrvmpiao]+$' {
                    foreach ($ch in $token.TrimStart('-').ToCharArray()) {
                        if ($ch -eq 'a') { & $enableAll }
                        elseif ($want.Contains([string]$ch)) { $want[[string]$ch] = $true }
                    }
                    break
                }
                default {
                    Write-Error "unrecognized option '$token'"
                    return
                }
            }
        }
    }

    # Default POSIX behavior: if no options specified, default to -s
    if (-not ($want.Values -contains $true)) { $want.s = $true }

    #### System Querying ####

    $needOs  = $want.s -or $want.r -or $want.v -or $want.m -or $want.i -or $want.o
    $needCpu = $want.p

    $wmiOs  = if ($needOs)  { Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue } else { $null }
    $wmiCpu = if ($needCpu) { Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1 } else { $null }

    # Helper: Registry reader for Windows NT build details
    $cvPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    function Get-RegistryValue { param([string]$Name)
        (Get-ItemProperty -Path $cvPath -Name $Name -ErrorAction SilentlyContinue).$Name
    }

    # -s: Kernel Name
    $val_s = if ($wmiOs) {
        if ($wmiOs.OtherTypeDescription -and $wmiOs.OtherTypeDescription.Trim()) {
            $wmiOs.OtherTypeDescription.Trim()
        } elseif ($wmiOs.OSType -eq 18) {
            'Windows_NT'
        } else {
            if ($Env:OS) { $Env:OS } else { "OSType$($wmiOs.OSType)" }
        }
    } elseif ($Env:OS) {
        $Env:OS
    } else {
        [System.Environment]::OSVersion.Platform.ToString()
    }

    # -n: Nodename
    $val_n = try {
        [System.Net.Dns]::GetHostName()
    } catch {
        $Env:COMPUTERNAME
    }

    # -r: Kernel Release (Version + UBR Patch level)
    $val_r = if ($wmiOs) {
        $ubr = Get-RegistryValue 'UBR'
        if ($null -ne $ubr) { "$($wmiOs.Version).$ubr" } else { $wmiOs.Version }
    } else {
        [System.Environment]::OSVersion.Version.ToString()
    }

    # -v: Kernel Version (#Build SMP InstallTimestamp)
    $val_v = if ($wmiOs) {
        $buildNum = $wmiOs.BuildNumber
        $installUtc = if ($wmiOs.InstallDate -is [datetime]) {
            $wmiOs.InstallDate.ToUniversalTime()
        } elseif ($wmiOs.InstallDate) {
            try { [Management.ManagementDateTimeConverter]::ToDateTime($wmiOs.InstallDate).ToUniversalTime() } catch { $null }
        } else { $null }

        if ($installUtc) {
            $dow    = $installUtc.ToString('ddd')
            $mon    = $installUtc.ToString('MMM')
            $day    = $installUtc.Day
            $dayPad = if ($day -lt 10) { " $day" } else { "$day" }
            $time   = $installUtc.ToString('HH:mm:ss')
            $year   = $installUtc.ToString('yyyy')
            "#$buildNum SMP $dow $mon $dayPad $time UTC $year"
        } else {
            "#$buildNum SMP"
        }
    } else {
        "#$([System.Environment]::OSVersion.Version.Build) SMP"
    }

    # -m / -i: Machine Hardware Architecture
    $archToken = $null
    try {
        $dotnetArch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
        $archToken = switch ($dotnetArch.ToString()) {
            'X64'   { 'x86_64'  }
            'X86'   { 'i686'    }
            'Arm64' { 'aarch64' }
            'Arm'   { 'armv7l'  }
            'S390x' { 's390x'   }
            default { $dotnetArch.ToString().ToLower() }
        }
    } catch { $archToken = $null }

    if (-not $archToken -and $wmiOs -and $wmiOs.OSArchitecture) {
        $archToken = switch -Wildcard ($wmiOs.OSArchitecture) {
            '*64-bit*' { 'x86_64'  }
            '*32-bit*' { 'i686'    }
            '*ARM*64*' { 'aarch64' }
            default    { $wmiOs.OSArchitecture }
        }
    }

    if (-not $archToken -and $Env:PROCESSOR_ARCHITECTURE) {
        $archToken = switch ($Env:PROCESSOR_ARCHITECTURE) {
            'AMD64' { 'x86_64'  }
            'ARM64' { 'aarch64' }
            'ARM'   { 'armv7l'  }
            'x86'   { 'i686'    }
            default { $Env:PROCESSOR_ARCHITECTURE.ToLower() }
        }
    }

    $val_m = if ($archToken) { $archToken } else { 'unknown' }
    $val_i = $val_m

    # -p: Processor Name
    $val_p = if ($wmiCpu -and $wmiCpu.Name -and $wmiCpu.Name.Trim()) {
        $wmiCpu.Name.Trim()
    } elseif ($Env:PROCESSOR_IDENTIFIER -and $Env:PROCESSOR_IDENTIFIER.Trim()) {
        $Env:PROCESSOR_IDENTIFIER.Trim()
    } else {
        $val_m
    }

    # -o: Operating System Marketing Name
    $val_o = if ($wmiOs -and $wmiOs.Caption -and $wmiOs.Caption.Trim()) {
        $wmiOs.Caption.Trim()
    } else {
        [System.Environment]::OSVersion.VersionString
    }

    #### Output formatting (POSIX field order: s n r v m p i o) ####

    $fieldValues = [ordered]@{
        s = $val_s
        n = $val_n
        r = $val_r
        v = $val_v
        m = $val_m
        p = $val_p
        i = $val_i
        o = $val_o
    }

    $parts = foreach ($key in $fieldValues.Keys) {
        if ($want[$key]) { $fieldValues[$key] }
    }

    Write-Output ($parts -join ' ')
}