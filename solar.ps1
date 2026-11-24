# Solar Tweaking Util - Windows 11 PowerShell GUI
# Independent implementation. Inspired by common Windows utility workflows.
# All registry actions are backed up before change; review each item before applying.

$ErrorActionPreference = 'Stop'
$script:SolarRoot = Join-Path $env:ProgramData 'SolarTweakingUtil'
$script:BackupRoot = Join-Path $script:SolarRoot 'Backups'
$script:LogFile = Join-Path $script:SolarRoot 'solar.log'
New-Item -ItemType Directory -Path $script:BackupRoot -Force | Out-Null

function Write-SolarLog([string]$Message) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Add-Content -LiteralPath $script:LogFile -Value $line -ErrorAction SilentlyContinue
}
function Test-SolarAdmin {
    $p = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Test-SolarAdmin)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/solar-tweaking-util/solar-tweaking-util/main/solar.ps1 | iex"'
    return
}

$script:Tweaks = @(
    [pscustomobject]@{ Name="Enable Game Mode"; Category="Gaming"; Path="HKCU:\\Software\\Microsoft\\GameBar"; ValueName="AutoGameModeEnabled"; Data=1; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Enable Game Mode capture preference"; Category="Gaming"; Path="HKCU:\\Software\\Microsoft\\GameBar"; ValueName="AllowAutoGameMode"; Data=1; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable Game DVR capture"; Category="Gaming"; Path="HKCU:\\System\\GameConfigStore"; ValueName="GameDVR_Enabled"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable Game DVR policy"; Category="Gaming"; Path="HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\GameDVR"; ValueName="AllowGameDVR"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable Xbox background recording"; Category="Gaming"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\GameDVR"; ValueName="AppCaptureEnabled"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Prefer high performance GPU scheduling"; Category="Gaming"; Path="HKLM:\\SYSTEM\\CurrentControlSet\\Control\\GraphicsDrivers"; ValueName="HwSchMode"; Data=2; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable fullscreen optimizations compatibility toggle"; Category="Gaming"; Path="HKCU:\\System\\GameConfigStore"; ValueName="GameDVR_FSEBehaviorMode"; Data=2; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Set game priority profile"; Category="Gaming"; Path="HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile"; ValueName="SystemResponsiveness"; Data=10; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Set games task GPU priority"; Category="Gaming"; Path="HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Games"; ValueName="GPU Priority"; Data=8; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Set games task CPU priority"; Category="Gaming"; Path="HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Games"; ValueName="Priority"; Data=6; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Show file extensions"; Category="Explorer"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced"; ValueName="HideFileExt"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Show hidden files"; Category="Explorer"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced"; ValueName="Hidden"; Data=1; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Show protected OS files"; Category="Explorer"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced"; ValueName="ShowSuperHidden"; Data=1; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Launch Explorer to This PC"; Category="Explorer"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced"; ValueName="LaunchTo"; Data=1; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable taskbar widgets button"; Category="Explorer"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced"; ValueName="TaskbarDa"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable taskbar chat button"; Category="Explorer"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced"; ValueName="TaskbarMn"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable search highlights"; Category="Explorer"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\SearchSettings"; ValueName="IsDynamicSearchBoxEnabled"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable recent files in Quick Access"; Category="Explorer"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer"; ValueName="ShowRecent"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable frequent folders in Quick Access"; Category="Explorer"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer"; ValueName="ShowFrequent"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Use classic context menu"; Category="Explorer"; Path="HKCU:\\Software\\Classes\\CLSID\\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\\InprocServer32"; ValueName=""; Data=""; Kind="String"; Protected=$false }
    [pscustomobject]@{ Name="Disable advertising ID"; Category="Privacy"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\AdvertisingInfo"; ValueName="Enabled"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable tailored experiences"; Category="Privacy"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Privacy"; ValueName="TailoredExperiencesWithDiagnosticDataEnabled"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable app launch tracking"; Category="Privacy"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced"; ValueName="Start_TrackProgs"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable suggested content"; Category="Privacy"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager"; ValueName="SubscribedContent-338387Enabled"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable tips and suggestions"; Category="Privacy"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager"; ValueName="SubscribedContent-338389Enabled"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable consumer experiences"; Category="Privacy"; Path="HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\CloudContent"; ValueName="DisableWindowsConsumerFeatures"; Data=1; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable activity history publishing"; Category="Privacy"; Path="HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System"; ValueName="PublishUserActivities"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable activity history upload"; Category="Privacy"; Path="HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System"; ValueName="UploadUserActivities"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable app diagnostic access"; Category="Privacy"; Path="HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\AppPrivacy"; ValueName="LetAppsGetDiagnosticInfo"; Data=2; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable online speech recognition"; Category="Privacy"; Path="HKCU:\\Software\\Microsoft\\Speech_OneCore\\Settings\\OnlineSpeechPrivacy"; ValueName="HasAccepted"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable transparency effects"; Category="Performance"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize"; ValueName="EnableTransparency"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Prefer performance visual effects"; Category="Performance"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\VisualEffects"; ValueName="VisualFXSetting"; Data=2; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable minimize/maximize animation"; Category="Performance"; Path="HKCU:\\Control Panel\\Desktop\\WindowMetrics"; ValueName="MinAnimate"; Data="0"; Kind="String"; Protected=$false }
    [pscustomobject]@{ Name="Set menu show delay to zero"; Category="Performance"; Path="HKCU:\\Control Panel\\Desktop"; ValueName="MenuShowDelay"; Data="0"; Kind="String"; Protected=$false }
    [pscustomobject]@{ Name="Disable mouse acceleration"; Category="Performance"; Path="HKCU:\\Control Panel\\Mouse"; ValueName="MouseSpeed"; Data="0"; Kind="String"; Protected=$false }
    [pscustomobject]@{ Name="Disable mouse threshold 1"; Category="Performance"; Path="HKCU:\\Control Panel\\Mouse"; ValueName="MouseThreshold1"; Data="0"; Kind="String"; Protected=$false }
    [pscustomobject]@{ Name="Disable mouse threshold 2"; Category="Performance"; Path="HKCU:\\Control Panel\\Mouse"; ValueName="MouseThreshold2"; Data="0"; Kind="String"; Protected=$false }
    [pscustomobject]@{ Name="Disable background app global policy"; Category="Performance"; Path="HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\AppPrivacy"; ValueName="LetAppsRunInBackground"; Data=2; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable lock screen tips"; Category="Performance"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager"; ValueName="RotatingLockScreenEnabled"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable app suggestions in Start"; Category="Performance"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager"; ValueName="SystemPaneSuggestionsEnabled"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable network throttling index"; Category="Network"; Path="HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile"; ValueName="NetworkThrottlingIndex"; Data=4294967295; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Set TCP time-wait delay"; Category="Network"; Path="HKLM:\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters"; ValueName="TcpTimedWaitDelay"; Data=30; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Set TCP keep-alive time"; Category="Network"; Path="HKLM:\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters"; ValueName="KeepAliveTime"; Data=300000; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable consumer Wi-Fi hotspot auto-connect"; Category="Network"; Path="HKLM:\\SOFTWARE\\Microsoft\\WcmSvc\\wifinetworkmanager\\config"; ValueName="AutoConnectAllowedOEM"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable Windows peer update sharing"; Category="Network"; Path="HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\DeliveryOptimization"; ValueName="DODownloadMode"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable Delivery Optimization peer mode"; Category="Network"; Path="HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\DeliveryOptimization\\Config"; ValueName="DODownloadMode"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Set DNS over HTTPS policy to automatic"; Category="Network"; Path="HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\DNSClient"; ValueName="DoHPolicy"; Data=2; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Set TCP maximum retransmission count"; Category="Network"; Path="HKLM:\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters"; ValueName="TcpMaxDataRetransmissions"; Data=5; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable restart notifications during active hours"; Category="Updates"; Path="HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU"; ValueName="NoAutoRebootWithLoggedOnUsers"; Data=1; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable update toast notifications"; Category="Updates"; Path="HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate"; ValueName="SetUpdateNotificationLevel"; Data=1; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable driver updates through Windows Update"; Category="Updates"; Path="HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate"; ValueName="ExcludeWUDriversInQualityUpdate"; Data=1; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Set automatic update notification-only policy"; Category="Updates"; Path="HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU"; ValueName="AUOptions"; Data=2; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Enable Storage Sense"; Category="Storage"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\StorageSense\\Parameters\\StoragePolicy"; ValueName="01"; Data=1; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Enable NTFS long paths"; Category="System"; Path="HKLM:\\SYSTEM\\CurrentControlSet\\Control\\FileSystem"; ValueName="LongPathsEnabled"; Data=1; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable error reporting prompts"; Category="System"; Path="HKLM:\\SOFTWARE\\Microsoft\\Windows\\Windows Error Reporting"; ValueName="Disabled"; Data=1; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable remote assistance"; Category="System"; Path="HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Remote Assistance"; ValueName="fAllowToGetHelp"; Data=0; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable AutoPlay"; Category="System"; Path="HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\AutoplayHandlers"; ValueName="DisableAutoplay"; Data=1; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable autorun"; Category="System"; Path="HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer"; ValueName="NoDriveTypeAutoRun"; Data=255; Kind="DWord"; Protected=$false }
    [pscustomobject]@{ Name="Disable sticky keys shortcut prompt"; Category="System"; Path="HKCU:\\Control Panel\\Accessibility\\StickyKeys"; ValueName="Flags"; Data="506"; Kind="String"; Protected=$false }
    [pscustomobject]@{ Name="Disable filter keys shortcut prompt"; Category="System"; Path="HKCU:\\Control Panel\\Accessibility\\Keyboard Response"; ValueName="Flags"; Data="122"; Kind="String"; Protected=$false }
    [pscustomobject]@{ Name="Disable toggle keys shortcut prompt"; Category="System"; Path="HKCU:\\Control Panel\\Accessibility\\ToggleKeys"; ValueName="Flags"; Data="58"; Kind="String"; Protected=$false }
    [pscustomobject]@{ Name="Disable Bluetooth service"; Category="Protected Controls"; Path=''; ValueName=''; Data="bthserv"; Kind='Protected'; Protected=$true }
    [pscustomobject]@{ Name="Disable Windows Update service"; Category="Protected Controls"; Path=''; ValueName=''; Data="wuauserv"; Kind='Protected'; Protected=$true }
    [pscustomobject]@{ Name="Disable Microsoft Defender real-time monitoring"; Category="Protected Controls"; Path=''; ValueName=''; Data="Defender"; Kind='Protected'; Protected=$true }
    [pscustomobject]@{ Name="Disable Windows Firewall profiles"; Category="Protected Controls"; Path=''; ValueName=''; Data="Firewall"; Kind='Protected'; Protected=$true }
    [pscustomobject]@{ Name="Disable SmartScreen reputation checks"; Category="Protected Controls"; Path=''; ValueName=''; Data="SmartScreen"; Kind='Protected'; Protected=$true }
)

function Get-BackupFile { Join-Path $script:BackupRoot 'registry-backup.json' }
function Save-RegistryBackup($Tweak) {
    $file = Get-BackupFile
    $all = @()
    if (Test-Path $file) { try { $all = @(Get-Content $file -Raw | ConvertFrom-Json) } catch {} }
    $existing = @($all | Where-Object { $_.Name -eq $Tweak.Name })
    if ($existing.Count -gt 0) { return }
    $key = Get-Item -LiteralPath $Tweak.Path -ErrorAction SilentlyContinue
    $exists = $false; $old = $null; $oldKind=$Tweak.Kind
    if ($key -and $Tweak.ValueName -ne '' -and $key.GetValueNames() -contains [string]$Tweak.ValueName) { $exists=$true; $old=$key.GetValue([string]$Tweak.ValueName,$null,'DoNotExpandEnvironmentNames'); try { $oldKind=[string]$key.GetValueKind([string]$Tweak.ValueName) } catch {} }
    $entry = [pscustomobject]@{ Name=$Tweak.Name; Path=$Tweak.Path; ValueName=$Tweak.ValueName; Exists=$exists; Data=$old; Kind=$Tweak.Kind; ValueKind=$oldKind; Date=(Get-Date).ToString('o') }
    $all += $entry
    $all | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $file -Encoding UTF8
}
function Apply-RegistryTweak($Tweak) {
    Save-RegistryBackup $Tweak
    if ($Tweak.ValueName -eq '' -and $Tweak.Kind -eq 'String') {
        New-Item -Path $Tweak.Path -Force | Out-Null
    } else {
        New-Item -Path $Tweak.Path -Force | Out-Null
        New-ItemProperty -LiteralPath $Tweak.Path -Name $Tweak.ValueName -Value $Tweak.Data -PropertyType $Tweak.Kind -Force | Out-Null
    }
    $actual = (Get-ItemProperty -LiteralPath $Tweak.Path -Name $Tweak.ValueName -ErrorAction SilentlyContinue).$($Tweak.ValueName)
    if ($Tweak.ValueName -ne '' -and [string]$actual -ne [string]$Tweak.Data) { throw "Verification failed for $($Tweak.Name)" }
    Write-SolarLog "APPLIED: $($Tweak.Name)"
}
function Restore-RegistryBackups {
    $file=Get-BackupFile
    $all=@()
    if (Test-Path $file) { $all=@(Get-Content $file -Raw | ConvertFrom-Json) }
    $restored=0; $failed=0
    foreach($b in $all) {
        try {
            if ($b.Exists) {
                New-Item -Path $b.Path -Force | Out-Null
                $kind=[string]$b.ValueKind
                if ($kind -notin @('String','ExpandString','MultiString','Binary','DWord','QWord')) { $kind='String' }
                New-ItemProperty -LiteralPath $b.Path -Name $b.ValueName -Value $b.Data -PropertyType $kind -Force | Out-Null
            } else { Remove-ItemProperty -LiteralPath $b.Path -Name $b.ValueName -ErrorAction SilentlyContinue }
            $restored++
        } catch { $failed++; Write-SolarLog "RESTORE FAILED: $($b.Name) - $_" }
    }
    # Restore protected service/security settings recorded by Solar.
    $pf=Join-Path $script:BackupRoot 'protected-backup.json'
    if (Test-Path $pf) {
        try {
            $pb=Get-Content $pf -Raw | ConvertFrom-Json
            foreach($x in $pb) {
                try {
                    switch($x.Type) {
                        'Bluetooth' { if($x.StartMode -eq 'Auto'){sc.exe config bthserv start= auto | Out-Null} elseif($x.StartMode -eq 'Manual'){sc.exe config bthserv start= demand | Out-Null} else {sc.exe config bthserv start= disabled | Out-Null}; if($x.State -eq 'Running'){Start-Service bthserv -ErrorAction SilentlyContinue} }
                        'Firewall' { foreach($pname in @('Domain','Private','Public')) { if($null -ne $x.$pname){Set-NetFirewallProfile -Profile $pname -Enabled ([bool]$x.$pname)} } }
                        'Defender' { Set-MpPreference -DisableRealtimeMonitoring ([bool]$x.Disabled) }
                    }
                    $restored++
                } catch { $failed++; Write-SolarLog "PROTECTED RESTORE FAILED: $($x.Type) - $_" }
            }
        } catch { $failed++; Write-SolarLog "Protected backup read failed: $_" }
    }
    Write-SolarLog "RESTORE finished: $restored restored, $failed failed"
    [System.Windows.MessageBox]::Show("Restore finished.`nRestored: $restored`nFailed: $failed`nSome settings may require sign-out or restart.",'Solar Restore') | Out-Null
}
function Get-PinHash([string]$Pin,[byte[]]$Salt) {
    $derive = [Security.Cryptography.Rfc2898DeriveBytes]::new($Pin,$Salt,180000,[Security.Cryptography.HashAlgorithmName]::SHA256)
    return [Convert]::ToBase64String($derive.GetBytes(32))
}
function Confirm-SolarPin {
    $pinFile=Join-Path $script:SolarRoot 'pin.dat'
    if (-not (Test-Path $pinFile)) {
        [System.Windows.MessageBox]::Show('First-time setup: enter your chosen Solar PIN (choose a PIN you will remember). It will be stored locally as a salted verifier. Do not put this PIN in the public GitHub script.','Solar Protected Controls') | Out-Null
        $p1=[Microsoft.VisualBasic.Interaction]::InputBox('Create your Solar authorization PIN:','Solar PIN Setup','')
        if ([string]::IsNullOrWhiteSpace($p1)) { return $false }
        $p2=[Microsoft.VisualBasic.Interaction]::InputBox('Confirm your Solar PIN:','Solar PIN Setup','')
        if ($p1 -ne $p2) { [System.Windows.MessageBox]::Show('PINs did not match.','Solar') | Out-Null; return $false }
        $salt=New-Object byte[] 16; [Security.Cryptography.RandomNumberGenerator]::Fill($salt)
        $record=[pscustomobject]@{ Salt=[Convert]::ToBase64String($salt); Hash=(Get-PinHash $p1 $salt) }
        $record | ConvertTo-Json | Set-Content -LiteralPath $pinFile -Encoding UTF8
        return $true
    }
    $record=Get-Content $pinFile -Raw | ConvertFrom-Json
    $salt=[Convert]::FromBase64String($record.Salt)
    $pin=[Microsoft.VisualBasic.Interaction]::InputBox('Enter your Solar authorization PIN:','Protected Controls','')
    if ([string]::IsNullOrWhiteSpace($pin)) { return $false }
    $ok=(Get-PinHash $pin $salt) -eq $record.Hash
    if (-not $ok) { [System.Windows.MessageBox]::Show('Incorrect PIN. No changes were made.','Solar') | Out-Null }
    return $ok
}
function Save-ProtectedBackup([string]$Type) {
    $file=Join-Path $script:BackupRoot 'protected-backup.json'; $all=@()
    if(Test-Path $file){try{$all=@(Get-Content $file -Raw | ConvertFrom-Json)}catch{}}
    if(@($all | Where-Object {$_.Type -eq $Type}).Count -gt 0){return}
    switch($Type){
        'Bluetooth' { $svc=Get-CimInstance Win32_Service -Filter "Name='bthserv'"; $all += [pscustomobject]@{Type='Bluetooth';StartMode=$svc.StartMode;State=$svc.State} }
        'Firewall' { $f=Get-NetFirewallProfile; $o=[ordered]@{Type='Firewall'}; foreach($p in $f){$o[$p.Name]=[bool]$p.Enabled}; $all += [pscustomobject]$o }
        'Defender' { $pref=Get-MpPreference; $all += [pscustomobject]@{Type='Defender';Disabled=[bool]$pref.DisableRealtimeMonitoring} }
    }
    $all | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $file -Encoding UTF8
}
function Apply-ProtectedControl($Tweak) {
    if (-not (Confirm-SolarPin)) { return }
    $warning="This changes a protected Windows feature: $($Tweak.Name). It can reduce security or connectivity. You can use Restore to return recorded settings. Continue?"
    if ([System.Windows.MessageBox]::Show($warning,'Solar Protected Control','YesNo','Warning') -ne 'Yes') { return }
    switch ($Tweak.Data) {
        'bthserv' {
            Save-ProtectedBackup 'Bluetooth'
            $svc=Get-CimInstance Win32_Service -Filter "Name='bthserv'"
            if ($svc) { sc.exe config bthserv start= disabled | Out-Null; Stop-Service bthserv -Force -ErrorAction SilentlyContinue }
        }
        'wuauserv' {
            # Do not force-disable Windows Update; pause via supported user settings instead.
            Start-Process 'ms-settings:windowsupdate' -ErrorAction SilentlyContinue
            [System.Windows.MessageBox]::Show('Windows Update settings opened. Use Pause updates there. Solar does not forcibly disable the servicing stack.','Solar') | Out-Null
        }
        'Defender' {
            Save-ProtectedBackup 'Defender'
            try { Set-MpPreference -DisableRealtimeMonitoring $true; [System.Windows.MessageBox]::Show('Requested Defender real-time protection change. Tamper Protection or policy may block/revert it. Solar does not bypass those protections.','Solar') | Out-Null } catch { throw $_ }
        }
        'Firewall' {
            Save-ProtectedBackup 'Firewall'
            Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False
        }
        'SmartScreen' {
            [System.Windows.MessageBox]::Show('SmartScreen controls are managed by Windows Security and policy. Solar will open the relevant settings rather than bypass protections.','Solar') | Out-Null
            Start-Process 'windowsdefender:'
        }
    }
    Write-SolarLog "PROTECTED ACTION REQUESTED: $($Tweak.Name)"
}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,Microsoft.VisualBasic
[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="SOLAR TWEAKING UTIL" Height="820" Width="1280" MinHeight="650" MinWidth="1000" WindowStartupLocation="CenterScreen" Background="#100D18" Foreground="#F4EEFF" FontFamily="Segoe UI">
 <Window.Resources>
  <Style TargetType="Button"><Setter Property="Background" Value="#7138B8"/><Setter Property="Foreground" Value="White"/><Setter Property="BorderThickness" Value="0"/><Setter Property="Padding" Value="13,8"/><Setter Property="Margin" Value="4"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Cursor" Value="Hand"/></Style>
  <Style TargetType="CheckBox"><Setter Property="Foreground" Value="#F0E8FF"/><Setter Property="Margin" Value="8,6"/><Setter Property="FontSize" Value="13"/></Style>
  <Style TargetType="TextBox"><Setter Property="Background" Value="#211A2D"/><Setter Property="Foreground" Value="White"/><Setter Property="BorderBrush" Value="#59416F"/><Setter Property="Padding" Value="9"/></Style>
  <Style TargetType="ComboBox"><Setter Property="Background" Value="#211A2D"/><Setter Property="Foreground" Value="#171020"/><Setter Property="Padding" Value="6"/></Style>
 </Window.Resources>
 <Grid Margin="14"><Grid.RowDefinitions><RowDefinition Height="70"/><RowDefinition Height="*"/><RowDefinition Height="36"/></Grid.RowDefinitions>
  <Border Grid.Row="0" Background="#21152F" CornerRadius="10" Padding="14" Margin="0,0,0,12"><DockPanel><StackPanel Orientation="Horizontal" DockPanel.Dock="Left"><Border Background="#813ED0" CornerRadius="9" Width="42" Height="42"><TextBlock Text="S" FontSize="29" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><StackPanel Margin="12,0,0,0" VerticalAlignment="Center"><TextBlock Text="SOLAR TWEAKING UTIL" FontSize="21" FontWeight="Bold"/><TextBlock Text="WINDOWS 11 PERFORMANCE • DEBLOAT • CONTROL" Foreground="#C4A5E8" FontSize="10"/></StackPanel></StackPanel><TextBlock x:Name="AdminLabel" Text="ADMINISTRATOR" Foreground="#CDAAFF" VerticalAlignment="Center" HorizontalAlignment="Right"/></DockPanel></Border>
  <Grid Grid.Row="1"><Grid.ColumnDefinitions><ColumnDefinition Width="210"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
   <Border Grid.Column="0" Background="#1B1525" CornerRadius="10" Padding="10" Margin="0,0,12,0"><StackPanel><TextBlock Text="WORKSPACE" Foreground="#A98AC8" FontWeight="Bold" Margin="8,8"/><ListBox x:Name="Categories" Background="Transparent" BorderThickness="0" Foreground="#F0E8FF" FontSize="14"/><Separator Margin="5,12" Background="#49345D"/><Button x:Name="ApplyBtn" Content="APPLY SELECTED"/><Button x:Name="RestoreBtn" Content="RESTORE BACKUPS" Background="#49345D"/><Button x:Name="AuditBtn" Content="SYSTEM AUDIT" Background="#49345D"/><Button x:Name="SelectBtn" Content="SELECT VISIBLE" Background="#49345D"/><Button x:Name="ClearBtn" Content="CLEAR SELECTION" Background="#49345D"/></StackPanel></Border>
   <Grid Grid.Column="1"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="100"/></Grid.RowDefinitions>
    <DockPanel Grid.Row="0" Margin="0,0,0,10"><StackPanel DockPanel.Dock="Left"><TextBlock x:Name="SectionTitle" Text="All Tweaks" FontSize="22" FontWeight="Bold"/><TextBlock x:Name="SectionSub" Text="Select changes to apply. Review descriptions before use." Foreground="#B7A6C9"/></StackPanel><TextBox x:Name="SearchBox" Width="290" Height="34" VerticalContentAlignment="Center" HorizontalAlignment="Right" ToolTip="Search tweaks"/></DockPanel>
    <Border Grid.Row="1" Background="#1B1525" CornerRadius="10" Padding="10"><ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel x:Name="TweakPanel"/></ScrollViewer></Border>
    <Border Grid.Row="2" Background="#21152F" CornerRadius="10" Padding="10" Margin="0,10,0,0"><DockPanel><StackPanel DockPanel.Dock="Left"><TextBlock Text="EXECUTION LOG" FontWeight="Bold" Foreground="#CDAAFF"/><TextBlock x:Name="StatusText" Text="Ready. No changes have been made." Margin="0,5,0,0"/></StackPanel><StackPanel HorizontalAlignment="Right" VerticalAlignment="Center"><TextBlock x:Name="CountText" Text="0 selected" Foreground="#CDAAFF"/><TextBlock Text="Changes may require sign-out or restart." Foreground="#9F91AE" FontSize="10"/></StackPanel></DockPanel></Border>
   </Grid>
  </Grid>
  <TextBlock Grid.Row="2" Text="SOLAR TWEAKING UTIL  •  LOCAL BACKUPS  •  REVIEW BEFORE APPLYING" Foreground="#8F7AA5" VerticalAlignment="Center" HorizontalAlignment="Center" FontSize="10"/>
 </Grid>
</Window>
'@
$reader=New-Object System.Xml.XmlNodeReader $xaml
$window=[Windows.Markup.XamlReader]::Load($reader)
$script:ui=@{}
'Categories','TweakPanel','SearchBox','SectionTitle','SectionSub','StatusText','CountText','ApplyBtn','RestoreBtn','AuditBtn','SelectBtn','ClearBtn','AdminLabel' | ForEach-Object { $script:ui[$_]=$window.FindName($_) }
$script:categories=@('All Tweaks') + @($script:Tweaks | Select-Object -ExpandProperty Category -Unique)
foreach($c in $script:categories){ [void]$script:ui.Categories.Items.Add($c) }
$script:ui.Categories.SelectedIndex=0
$script:checks=New-Object System.Collections.ArrayList
function Refresh-TweakList {
    $script:ui.TweakPanel.Children.Clear(); $script:checks.Clear()
    $cat=[string]$script:ui.Categories.SelectedItem; $q=[string]$script:ui.SearchBox.Text
    $filtered=@($script:Tweaks | Where-Object { ($cat -eq 'All Tweaks' -or $_.Category -eq $cat) -and ($_.Name -like "*$q*" -or $_.Category -like "*$q*") })
    $script:ui.SectionTitle.Text=$cat
    $script:ui.SectionSub.Text="$($filtered.Count) available actions • Registry changes are backed up before applying"
    foreach($t in $filtered){
        $border=New-Object Windows.Controls.Border; $border.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#241C31'); $border.CornerRadius='6'; $border.Margin='3'; $border.Padding='8'
        $sp=New-Object Windows.Controls.StackPanel
        $cb=New-Object Windows.Controls.CheckBox; $cb.Content=$t.Name; $cb.Tag=$t; $cb.FontWeight='SemiBold'
        $desc=New-Object Windows.Controls.TextBlock; $desc.Text=if($t.Protected){'PROTECTED CONTROL • Requires Solar PIN and separate confirmation'}else{"$($t.Category) • Saves the previous registry value before applying"}; $desc.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString('#B5A3C9'); $desc.FontSize=10; $desc.Margin='28,0,0,0'
        [void]$sp.Children.Add($cb); [void]$sp.Children.Add($desc); $border.Child=$sp; [void]$script:ui.TweakPanel.Children.Add($border); [void]$script:checks.Add($cb)
        $cb.Add_Checked({ Update-Count }); $cb.Add_Unchecked({ Update-Count })
    }
    Update-Count
}
function Update-Count { $n=@($script:checks | Where-Object {$_.IsChecked}).Count; $script:ui.CountText.Text="$n selected" }
$script:ui.Categories.Add_SelectionChanged({ Refresh-TweakList })
$script:ui.SearchBox.Add_TextChanged({ Refresh-TweakList })
$script:ui.SelectBtn.Add_Click({ foreach($c in $script:checks){$c.IsChecked=$true}; Update-Count })
$script:ui.ClearBtn.Add_Click({ foreach($c in $script:checks){$c.IsChecked=$false}; Update-Count })
$script:ui.RestoreBtn.Add_Click({ Restore-RegistryBackups })
$script:ui.AuditBtn.Add_Click({
    $os=Get-CimInstance Win32_OperatingSystem; $cpu=Get-CimInstance Win32_Processor | Select-Object -First 1; $gpu=Get-CimInstance Win32_VideoController | Select-Object -First 1
    $msg="OS: $($os.Caption)`nBuild: $($os.BuildNumber)`nCPU: $($cpu.Name)`nGPU: $($gpu.Name)`nRAM: $([math]::Round($os.TotalVisibleMemorySize/1MB,1)) GB`nProcesses: $((Get-Process).Count)`n`nThis is an inventory only; no settings changed."
    [System.Windows.MessageBox]::Show($msg,'Solar System Audit') | Out-Null
})
$script:ui.ApplyBtn.Add_Click({
    $selected=@($script:checks | Where-Object {$_.IsChecked} | ForEach-Object {$_.Tag})
    if($selected.Count -eq 0){ [System.Windows.MessageBox]::Show('Select at least one action.','Solar') | Out-Null; return }
    $normal=@($selected | Where-Object {-not $_.Protected}); $protected=@($selected | Where-Object {$_.Protected})
    $confirm=[System.Windows.MessageBox]::Show("Apply $($normal.Count) standard changes and request $($protected.Count) protected controls?`n`nA backup is created before each registry change. Some tweaks may not improve FPS and may require restart.",'Confirm Solar Changes','YesNo','Warning')
    if($confirm -ne 'Yes'){return}
    $ok=0;$fail=0
    foreach($t in $normal){ try { Apply-RegistryTweak $t; $ok++ } catch { $fail++; Write-SolarLog "FAILED: $($t.Name) - $_" } }
    foreach($t in $protected){ try { Apply-ProtectedControl $t; $ok++ } catch { $fail++; Write-SolarLog "PROTECTED FAILED: $($t.Name) - $_" } }
    $script:ui.StatusText.Text="Finished: $ok successful actions, $fail failed. See $script:LogFile"
    [System.Windows.MessageBox]::Show("Completed.`nSuccessful: $ok`nFailed: $fail`nLog: $script:LogFile`nRestart or sign out may be required.",'Solar Results') | Out-Null
})
$script:ui.AdminLabel.Text="ADMINISTRATOR • $($script:Tweaks.Count) ACTIONS"
Refresh-TweakList
[void]$window.ShowDialog()