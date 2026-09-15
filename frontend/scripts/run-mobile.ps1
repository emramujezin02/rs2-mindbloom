param(
    [string] $AvdName = "MindBloom_Clean_API34",
    [string] $ApiBaseUrl = "http://10.0.2.2:5110",
    [string] $FlutterSdk,
    [string] $StripePublishableKey,
    [switch] $NoStartEmulator,
    [switch] $KeepOldFlutterProcesses,
    [switch] $KeepOldJavaProcesses
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string] $Message)
    Write-Host "==> $Message"
}

function Find-Flutter {
    if ($FlutterSdk) {
        if ($FlutterSdk -like "C:\Program Files\flutter\*") {
            throw "The old Flutter SDK under C:\Program Files\flutter must not be used. Pass the writable SDK path or unset the old SDK environment values."
        }

        return $FlutterSdk
    }

    $preferred = "C:\Users\emram\dev\flutter\bin\flutter.bat"
    if (Test-Path $preferred) {
        return $preferred
    }

    if ($env:FLUTTER_ROOT) {
        $candidate = Join-Path $env:FLUTTER_ROOT "bin\flutter.bat"
        if ((Test-Path $candidate) -and ($candidate -notlike "C:\Program Files\flutter\*")) {
            return $candidate
        }
    }

    $fromPath = Get-Command flutter -ErrorAction SilentlyContinue
    if ($fromPath) {
        if ($fromPath.Source -like "C:\Program Files\flutter\*") {
            throw "PATH resolves flutter to C:\Program Files\flutter. Put C:\Users\emram\dev\flutter\bin before the old SDK or pass -FlutterSdk."
        }

        return $fromPath.Source
    }

    throw "Flutter was not found. Set FLUTTER_ROOT or pass -FlutterSdk."
}

function Use-SelectedFlutterSdk {
    param([string] $Flutter)

    $flutterBin = Split-Path -Parent $Flutter
    $flutterRoot = Split-Path -Parent $flutterBin

    if ($flutterRoot -like "C:\Program Files\flutter*") {
        throw "The old Flutter SDK under C:\Program Files\flutter must not be used."
    }

    $pathEntries = $env:Path -split ";" |
        Where-Object { $_ -and ($_ -notlike "C:\Program Files\flutter*") }

    $env:FLUTTER_ROOT = $flutterRoot
    $env:Path = (@($flutterBin) + $pathEntries) -join ";"
}

function Use-FlutterJdkConfiguration {
    param(
        [string] $Flutter,
        [string] $JavaHome
    )

    Write-Step "Configuring Flutter to use Android Studio JBR"
    & $Flutter config "--jdk-dir=$JavaHome" | Out-Null
}

function Stop-OldFlutterProcesses {
    if ($KeepOldFlutterProcesses) {
        return
    }

    $attempt = 0
    while ($attempt -lt 3) {
        $oldProcesses = Get-Process -Name dart,flutter -ErrorAction SilentlyContinue |
            Where-Object { $_.Path -like "C:\Program Files\flutter\*" }

        if (-not $oldProcesses) {
            return
        }

        if ($attempt -eq 0) {
            Write-Step "Stopping old C:\Program Files\flutter Dart/Flutter processes"
        }

        foreach ($process in $oldProcesses) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }

        Start-Sleep -Seconds 1
        $attempt += 1
    }
}

function Stop-OldAndroidStudioJavaProcesses {
    if ($KeepOldJavaProcesses) {
        return
    }

    $oldJavaProcesses = Get-Process -Name java -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "C:\Program Files\Android\Android Studio4\jbr\*" }

    if (-not $oldJavaProcesses) {
        return
    }

    Write-Step "Stopping old Android Studio4 JBR Java processes"

    foreach ($process in $oldJavaProcesses) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
}

function Use-AndroidStudioJbr {
    $preferredJbr = "C:\Program Files\Android\Android Studio\jbr"

    if (Test-Path $preferredJbr) {
        if ($env:JAVA_HOME -and $env:JAVA_HOME -ne $preferredJbr) {
            Write-Step "Using Android Studio JBR for this run instead of JAVA_HOME=$env:JAVA_HOME"
        }

        $env:JAVA_HOME = $preferredJbr

        $pathEntries = $env:Path -split ";" |
            Where-Object { $_ -and ($_ -notlike "C:\Program Files\Android\Android Studio4\jbr\bin*") }

        $env:Path = (@(Join-Path $preferredJbr "bin") + $pathEntries) -join ";"
        return
    }

    if (-not $env:JAVA_HOME) {
        throw "JAVA_HOME is not set. Install Android Studio or set JAVA_HOME to its bundled JBR."
    }

    if (-not (Test-Path $env:JAVA_HOME)) {
        throw "JAVA_HOME points to a missing directory: $env:JAVA_HOME"
    }
}

function Find-AndroidTool {
    param([string] $RelativePath)

    $sdkRoot = $env:ANDROID_SDK_ROOT
    if (-not $sdkRoot) {
        $sdkRoot = $env:ANDROID_HOME
    }
    if (-not $sdkRoot) {
        $sdkRoot = Join-Path $env:LOCALAPPDATA "Android\Sdk"
    }

    $candidate = Join-Path $sdkRoot $RelativePath
    if (Test-Path $candidate) {
        return $candidate
    }

    throw "Android SDK tool not found: $candidate"
}

function Get-AdbDevices {
    param([string] $Adb)

    & $Adb devices | Select-String -Pattern "^(emulator|[A-Za-z0-9_-]+)\S*\s+device$"
}

function Get-AdbDeviceStates {
    param([string] $Adb)

    & $Adb devices |
        Select-Object -Skip 1 |
        ForEach-Object {
            $line = $_.Trim()
            if ($line -match "^(\S+)\s+(\S+)") {
                [pscustomobject]@{
                    Serial = $Matches[1]
                    State = $Matches[2]
                }
            }
        }
}

function Get-FirstAdbDeviceId {
    param([string] $Adb)

    $line = & $Adb devices |
        Select-String -Pattern "^(emulator|[A-Za-z0-9_-]+)\S*\s+device$" |
        Select-Object -First 1

    if (-not $line) {
        return $null
    }

    return ($line.Line -split "\s+")[0]
}

function Test-EmulatorProcessRunning {
    param([string] $AvdName)

    $processes = Get-CimInstance Win32_Process |
        Where-Object {
            ($_.Name -in @("emulator.exe", "qemu-system-x86_64.exe")) -and
            ($_.CommandLine -like "*$AvdName*" -or $_.CommandLine -like "*$AvdName.avd*")
        }

    return $null -ne $processes
}

function Get-TargetEmulatorProcesses {
    param([string] $AvdName)

    Get-CimInstance Win32_Process |
        Where-Object {
            ($_.Name -in @("emulator.exe", "qemu-system-x86_64.exe")) -and
            ($_.CommandLine -like "*$AvdName*" -or $_.CommandLine -like "*$AvdName.avd*")
        }
}

function Assert-AvdExists {
    param(
        [string] $Emulator,
        [string] $AvdName
    )

    $avds = & $Emulator -list-avds
    if ($avds -notcontains $AvdName) {
        throw "Android AVD '$AvdName' was not found. Available AVDs: $($avds -join ', ')"
    }
}

function Start-MindBloomEmulator {
    param(
        [string] $Emulator,
        [string] $AvdName
    )

    Write-Step "Starting Android emulator $AvdName"
Start-Process -FilePath $Emulator -ArgumentList @(
    "-avd", $AvdName,
    "-gpu", "swiftshader_indirect",
    "-no-snapshot-load",
    "-no-snapshot-save",
    "-no-boot-anim"
) -WindowStyle Hidden
}

function Stop-TargetEmulatorProcesses {
    param([string] $AvdName)

    $processes = Get-TargetEmulatorProcesses -AvdName $AvdName
    if (-not $processes) {
        return
    }

    Write-Step "Stopping stale Android emulator process for $AvdName"
    foreach ($process in $processes) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }

    Start-Sleep -Seconds 3
}

function Wait-ForDevice {
    param(
        [string] $Adb,
        [string] $Emulator,
        [string] $AvdName,
        [bool] $NoStart
    )

    Write-Step "Waiting for ADB device"

    $deadline = (Get-Date).AddSeconds(180)
    $adbRestarted = $false
    $targetRestarted = $false
    while ((Get-Date) -lt $deadline) {
        $devices = Get-AdbDevices -Adb $Adb
        if ($devices) {
            return
        }

        $states = @(Get-AdbDeviceStates -Adb $Adb)
        $stateSummary = if ($states.Count -gt 0) {
            ($states | ForEach-Object { "$($_.Serial):$($_.State)" }) -join ", "
        }
        else {
            "none"
        }

        if (-not $adbRestarted -and ($states.State -contains "offline" -or $states.State -contains "unauthorized")) {
            Write-Step "Recovering stale ADB state ($stateSummary)"
            & $Adb kill-server | Out-Null
            & $Adb start-server | Out-Null
            $adbRestarted = $true
            Start-Sleep -Seconds 5
            continue
        }

        $targetProcesses = @(Get-TargetEmulatorProcesses -AvdName $AvdName)
        if ($targetProcesses.Count -eq 0 -and -not $NoStart) {
            Start-MindBloomEmulator -Emulator $Emulator -AvdName $AvdName
            Start-Sleep -Seconds 5
            continue
        }

        $secondsRemaining = [int]($deadline - (Get-Date)).TotalSeconds
        if (-not $targetRestarted -and -not $NoStart -and $targetProcesses.Count -gt 0 -and $secondsRemaining -lt 90 -and $states.Count -eq 0) {
            Stop-TargetEmulatorProcesses -AvdName $AvdName
            Start-MindBloomEmulator -Emulator $Emulator -AvdName $AvdName
            $targetRestarted = $true
            $deadline = (Get-Date).AddSeconds(180)
            Start-Sleep -Seconds 5
            continue
        }

        Start-Sleep -Seconds 2
    }

    $finalStates = @(Get-AdbDeviceStates -Adb $Adb)
    $finalSummary = if ($finalStates.Count -gt 0) {
        ($finalStates | ForEach-Object { "$($_.Serial):$($_.State)" }) -join ", "
    }
    else {
        "none"
    }

    throw "ADB did not report a usable emulator/device within 180 seconds. Final ADB state: $finalSummary"
}

function Wait-ForBoot {
    param([string] $Adb)

    Write-Step "Waiting for Android boot completion"
    $deadline = (Get-Date).AddSeconds(240)

    while ((Get-Date) -lt $deadline) {
        $bootCompleted = (& $Adb shell getprop sys.boot_completed 2>$null).Trim()
        if ($bootCompleted -eq "1") {
            return
        }

        Start-Sleep -Seconds 3
    }

    throw "Android did not finish booting within 240 seconds."
}

function Invoke-AdbShell {
    param(
        [string] $Adb,
        [string[]] $Arguments,
        [int] $TimeoutSeconds = 5
    )

    $escapedArguments = @("shell") + ($Arguments | ForEach-Object {
        if ($_ -match '[\s"]') {
            '"' + ($_ -replace '"', '\"') + '"'
        }
        else {
            $_
        }
    })

    $processInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $processInfo.FileName = $Adb
    $processInfo.Arguments = $escapedArguments -join " "
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $processInfo

    try {
        $null = $process.Start()

        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            try {
                if (-not $process.HasExited) {
                    $process.Kill()
                }
            }
            catch {
                # Timeout je već dovoljan signal.
                # Ne rušimo cijeli mobile startup ako Windows
                # odbije gašenje zaglavljenog adb procesa.
            }

            return [pscustomobject]@{
                Success  = $false
                TimedOut = $true
                Output   = ""
            }
        }

        $output =
            $process.StandardOutput.ReadToEnd() +
            $process.StandardError.ReadToEnd()

        $exitCode = $process.ExitCode

        return [pscustomobject]@{
            Success  = $exitCode -eq 0
            TimedOut = $false
            Output   = $output
        }
    }
    catch {
        return [pscustomobject]@{
            Success  = $false
            TimedOut = $false
            Output   = $_.Exception.Message
        }
    }
    finally {
        $process.Dispose()
    }
}

function Set-EmulatorAnimationScale {
    param([string] $Adb)

    Write-Step "Reducing emulator animation overhead"

    $settings = @(
        @("settings", "put", "global", "window_animation_scale", "0.5"),
        @("settings", "put", "global", "transition_animation_scale", "0.5"),
        @("settings", "put", "global", "animator_duration_scale", "0.5")
    )

    foreach ($setting in $settings) {
        $null = Invoke-AdbShell -Adb $Adb -Arguments $setting -TimeoutSeconds 5
    }
}

function Wait-ForAndroidReady {
    param([string] $Adb)

    Write-Step "Waiting for Android system services to settle"

    $checks = @(
        @{
            Name = "shell"
            Arguments = @("echo", "ready")
            Match = "ready"
        },
        @{
            Name = "package manager"
            Arguments = @("cmd", "package", "path", "android")
            Match = "package:"
        },
        @{
            Name = "boot animation"
            Arguments = @("getprop", "init.svc.bootanim")
            Match = "stopped"
        },
        @{
            Name = "display"
            Arguments = @("wm", "size")
            Match = "Physical size:"
        }
    )

    $deadline = (Get-Date).AddSeconds(90)
    $lastFailedCheck = $null
    while ((Get-Date) -lt $deadline) {
        $allReady = $true

        foreach ($check in $checks) {
            $result = Invoke-AdbShell -Adb $Adb -Arguments $check.Arguments -TimeoutSeconds 15

            if ($result.TimedOut -or -not $result.Success -or ($result.Output -notmatch $check.Match)) {
                $allReady = $false
                $lastFailedCheck = $check.Name
                break
            }
        }

        if ($allReady) {
            Start-Sleep -Seconds 5
            return
        }

        Start-Sleep -Seconds 3
    }

    throw "Android booted, but core system services did not become responsive within 90 seconds. Last failed check: $lastFailedCheck."
}

function Wait-ForAndroidUiReady {
    param([string] $Adb)

    Write-Step "Waiting for Android launcher and System UI readiness"

    $deadline = (Get-Date).AddSeconds(60)
    $lastStatus = "not checked"

    while ((Get-Date) -lt $deadline) {
        $systemUi = Invoke-AdbShell `
            -Adb $Adb `
            -Arguments @("pidof", "com.android.systemui") `
            -TimeoutSeconds 5

        if (
            $systemUi.TimedOut -or
            -not $systemUi.Success -or
            [string]::IsNullOrWhiteSpace($systemUi.Output)
        ) {
            $lastStatus = "System UI process unavailable"
            Start-Sleep -Seconds 2
            continue
        }

        $launcher = Invoke-AdbShell `
            -Adb $Adb `
            -Arguments @(
                "cmd",
                "package",
                "resolve-activity",
                "--brief",
                "android.intent.action.MAIN",
                "-c",
                "android.intent.category.HOME"
            ) `
            -TimeoutSeconds 5

        if (
            $launcher.TimedOut -or
            -not $launcher.Success -or
            [string]::IsNullOrWhiteSpace($launcher.Output)
        ) {
            $lastStatus = "launcher did not resolve"
            Start-Sleep -Seconds 2
            continue
        }

        $shellProbe = Invoke-AdbShell `
            -Adb $Adb `
            -Arguments @("echo", "ready") `
            -TimeoutSeconds 5

        if (
            $shellProbe.TimedOut -or
            -not $shellProbe.Success -or
            $shellProbe.Output -notmatch "ready"
        ) {
            $lastStatus = "ADB shell not responsive"
            Start-Sleep -Seconds 2
            continue
        }

        Write-Step "Android launcher and System UI are ready"

        Start-Sleep -Seconds 5
        return
    }

    throw "Android booted, but launcher/System UI did not become responsive within 60 seconds. Last status: $lastStatus."
}

function Read-LocalValue {
    param(
        [string] $FilePath,
        [string] $Key
    )

    if (-not (Test-Path $FilePath)) {
        return $null
    }

    $line = Get-Content $FilePath |
        Where-Object { $_ -match "^\s*$([regex]::Escape($Key))\s*=" } |
        Select-Object -First 1

    if (-not $line) {
        return $null
    }

    return ($line -replace "^\s*$([regex]::Escape($Key))\s*=\s*", "").Trim().Trim('"').Trim("'")
}

function Test-TcpPort {
    param(
        [string] $HostName,
        [int] $Port,
        [int] $TimeoutMilliseconds = 1500
    )

    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $connect = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $connect.AsyncWaitHandle.WaitOne($TimeoutMilliseconds)) {
            return $false
        }

        $client.EndConnect($connect)
        return $true
    }
    catch {
        return $false
    }
    finally {
        $client.Close()
    }
}

function Test-HttpEndpoint {
    param(
        [string] $Url,
        [int] $TimeoutMilliseconds = 3000
    )

    $request = [System.Net.HttpWebRequest] [System.Net.WebRequest]::Create($Url)
    $request.Method = "GET"
    $request.Timeout = $TimeoutMilliseconds
    $request.ReadWriteTimeout = $TimeoutMilliseconds
    $request.AllowAutoRedirect = $false

    try {
        $response = $request.GetResponse()
        try {
            return [pscustomobject]@{
                Url = $Url
                Reached = $true
                TimedOut = $false
                StatusCode = [int] $response.StatusCode
                Message = "HTTP $([int] $response.StatusCode)"
            }
        }
        finally {
            $response.Close()
        }
    }
    catch [System.Net.WebException] {
        $webException = $_.Exception

        if ($webException.Status -eq [System.Net.WebExceptionStatus]::ProtocolError -and $webException.Response) {
            $response = [System.Net.HttpWebResponse] $webException.Response
            try {
                return [pscustomobject]@{
                    Url = $Url
                    Reached = $true
                    TimedOut = $false
                    StatusCode = [int] $response.StatusCode
                    Message = "HTTP $([int] $response.StatusCode)"
                }
            }
            finally {
                $response.Close()
            }
        }

        return [pscustomobject]@{
            Url = $Url
            Reached = $false
            TimedOut = $webException.Status -eq [System.Net.WebExceptionStatus]::Timeout
            StatusCode = $null
            Message = "$($webException.Status): $($webException.Message)"
        }
    }
}

function Test-ApiReady {
    $httpChecks = @(
        "http://127.0.0.1:5110/health/live",
        "http://127.0.0.1:5110/swagger/index.html",
        "http://127.0.0.1:5110/swagger",
        "http://127.0.0.1:5110/",
        "http://localhost:5110/health/live",
        "http://localhost:5110/swagger/index.html",
        "http://localhost:5110/swagger"
    )

    $results = @()
    foreach ($url in $httpChecks) {
        $result = Test-HttpEndpoint -Url $url
        $results += $result

        if ($result.Reached) {
            Write-Step "API reachable at $($result.Url) ($($result.Message))"
            return
        }
    }

    $tcpReachable = (Test-TcpPort -HostName "127.0.0.1" -Port 5110) -or
        (Test-TcpPort -HostName "localhost" -Port 5110)

    if ($tcpReachable) {
        $lastMessage = ($results | Select-Object -Last 1).Message
        Write-Warning "Port 5110 is accepting TCP connections, but HTTP readiness requests did not complete cleanly. Continuing because Kestrel is listening. Last HTTP check: $lastMessage"
        return
    }

    $firstResult = $results | Select-Object -First 1

    if ($firstResult.TimedOut) {
        throw "MindBloom API port 5110 is not accepting TCP connections, and the HTTP readiness request timed out. Start MindBloom.API with the HTTP profile."
    }

    throw "MindBloom API is not listening on port 5110. Start MindBloom.API with the HTTP profile. Last check: $($firstResult.Message)"
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$mobileRoot = Join-Path $repoRoot "mindbloom_mobile"

$flutter = Find-Flutter
Use-SelectedFlutterSdk -Flutter $flutter
Stop-OldFlutterProcesses

$adb = Find-AndroidTool "platform-tools\adb.exe"
$emulator = Find-AndroidTool "emulator\emulator.exe"

Use-AndroidStudioJbr
Use-FlutterJdkConfiguration -Flutter $flutter -JavaHome $env:JAVA_HOME
Stop-OldAndroidStudioJavaProcesses
Assert-AvdExists -Emulator $emulator -AvdName $AvdName
& $adb start-server | Out-Null

if (-not $StripePublishableKey) {
    $StripePublishableKey = $env:STRIPE_PUBLISHABLE_KEY
}
if (-not $StripePublishableKey) {
    $StripePublishableKey = Read-LocalValue -FilePath (Join-Path $repoRoot ".env.local") -Key "STRIPE_PUBLISHABLE_KEY"
}
if (-not $StripePublishableKey) {
    $StripePublishableKey = "pk_test_local_development_placeholder"
    Write-Warning "Using a placeholder Stripe publishable key. Payment flows need a real pk_test_ key in STRIPE_PUBLISHABLE_KEY or frontend\.env.local."
}

if (-not $StripePublishableKey.StartsWith("pk_test_")) {
    throw "STRIPE_PUBLISHABLE_KEY must be a Stripe test publishable key starting with pk_test_."
}

$runningDevices = Get-AdbDevices -Adb $adb
if (-not $runningDevices -and (Test-EmulatorProcessRunning -AvdName $AvdName)) {
    Write-Step "Waiting for already starting Android emulator $AvdName"
}
elseif (-not $runningDevices -and -not $NoStartEmulator) {
    Start-MindBloomEmulator -Emulator $emulator -AvdName $AvdName
}
elseif ($runningDevices) {
    Write-Step "Using already connected Android device/emulator"
}
else {
    throw "No Android device/emulator is connected and -NoStartEmulator was used."
}

Wait-ForDevice -Adb $adb -Emulator $emulator -AvdName $AvdName -NoStart $NoStartEmulator.IsPresent
Wait-ForBoot -Adb $adb
Wait-ForAndroidReady -Adb $adb
Wait-ForAndroidUiReady -Adb $adb
Set-EmulatorAnimationScale -Adb $adb
$deviceId = Get-FirstAdbDeviceId -Adb $adb

if (-not $deviceId) {
    throw "ADB did not report a target device after Android readiness checks."
}

Write-Step "Checking API from Windows host"
Test-ApiReady

if ($ApiBaseUrl -match "^http://(127\.0\.0\.1|localhost):5110/?$") {
    Write-Step "Configuring ADB reverse for MindBloom API"
    & $adb -s $deviceId reverse tcp:5110 tcp:5110

    if ($LASTEXITCODE -ne 0) {
        throw "ADB reverse for port 5110 could not be configured."
    }

    $reverseMappings = & $adb -s $deviceId reverse --list

    if ($reverseMappings -notmatch "tcp:5110\s+tcp:5110") {
        throw "ADB reverse for port 5110 was not confirmed."
    }

    Write-Step "ADB reverse configured: emulator 127.0.0.1:5110 -> Windows 127.0.0.1:5110"
}
else {
    Write-Step "Using direct device API URL $ApiBaseUrl"
}

Write-Step "Running Flutter mobile app on $deviceId with API_BASE_URL=$ApiBaseUrl"
Stop-OldFlutterProcesses
Push-Location $mobileRoot
try {
& $flutter run `
    -d $deviceId `
    --no-pub `
    --no-enable-impeller `
    --dart-define=API_BASE_URL=$ApiBaseUrl `
    --dart-define=STRIPE_PUBLISHABLE_KEY=$StripePublishableKey
}
finally {
    Pop-Location
}
