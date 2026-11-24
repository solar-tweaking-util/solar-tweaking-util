# Solar Tweaking Util - compact WinUtil-inspired Windows 11 utility
# Release marker: 2026-11-24T01:06Z - independent Solar WPF build; no WinUtil logo patcher.
# Independent PowerShell/WPF implementation. Requires Windows PowerShell 5.1+ and Administrator.
# Registry preferences are backed up before modification. Review descriptions before applying.
# This utility does not bypass Tamper Protection, Secure Boot, driver protections, or thermal safeguards.

#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

function Test-SolarAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Test-SolarAdmin)) {
    # When launched with irm | iex, PSCommandPath is empty. Re-fetch this script in the elevated process.
    $solarUrl = 'https://raw.githubusercontent.com/solar-tweaking-util/solar-tweaking-util/main/solar.ps1'
    $elevatedCommand = "-NoProfile -ExecutionPolicy Bypass -Command `"irm '$solarUrl' | iex`""
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $elevatedCommand
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$script:Root = Join-Path $env:ProgramData 'SolarTweakingUtil'
$script:BackupRoot = Join-Path $script:Root 'Backups'
$script:LogPath = Join-Path $script:Root 'Solar.log'
New-Item -ItemType Directory -Path $script:BackupRoot -Force | Out-Null
$script:SessionBackup = Join-Path $script:BackupRoot ("Session-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $script:SessionBackup -Force | Out-Null
$script:BackupFile = Join-Path $script:SessionBackup 'registry.json'
$script:ServiceBackup = Join-Path $script:SessionBackup 'services.json'
$script:ChangedRegistry = @{}
$script:ChangedServices = @{}

function Write-Log([string]$Message) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $script:LogPath -Value $line
    if ($script:LogBox) {
        $script:LogBox.AppendText($line + [Environment]::NewLine)
        $script:LogBox.ScrollToEnd()
    }
    if ($script:StatusText) { $script:StatusText.Text = $Message }
}

function Get-RegistryValueState([string]$Path, [string]$Name) {
    $keyPath = "Registry::HKEY_CURRENT_USER\$Path"
    $key = Get-Item -LiteralPath $keyPath -ErrorAction SilentlyContinue
    if (-not $key) { return [pscustomobject]@{ Exists=$false; Value=$null; Kind='DWord' } }
    try {
        $value = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($null -eq $value -and $key.GetValueNames() -notcontains $Name) {
            return [pscustomobject]@{ Exists=$false; Value=$null; Kind='DWord' }
        }
        $kind = $key.GetValueKind($Name).ToString()
        return [pscustomobject]@{ Exists=$true; Value=$value; Kind=$kind }
    } finally { $key.Close() }
}

function Save-RegistryState([string]$Path, [string]$Name) {
    $id = "$Path|$Name"
    if ($script:ChangedRegistry.ContainsKey($id)) { return }
    $state = Get-RegistryValueState -Path $Path -Name $Name
    $script:ChangedRegistry[$id] = [pscustomobject]@{
        Path=$Path; Name=$Name; Exists=$state.Exists; Value=$state.Value; Kind=$state.Kind
    }
    @($script:ChangedRegistry.Values) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $script:BackupFile -Encoding UTF8
}

function Set-SolarRegistryValue($Tweak) {
    Save-RegistryState -Path $Tweak.Path -Name $Tweak.Name
    $keyPath = "Registry::HKEY_CURRENT_USER\$($Tweak.Path)"
    if (-not (Test-Path -LiteralPath $keyPath)) { New-Item -Path $keyPath -Force | Out-Null }
    $kind = [Microsoft.Win32.RegistryValueKind]::$($Tweak.Kind)
    $key = Get-Item -LiteralPath $keyPath
    try { $key.SetValue($Tweak.Name, $Tweak.Value, $kind) } finally { $key.Close() }
}

function Restore-RegistryBackup([string]$File) {
    if (-not (Test-Path -LiteralPath $File)) { return }
    $items = @(Get-Content -LiteralPath $File -Raw | ConvertFrom-Json)
    foreach ($item in $items) {
        try {
            $keyPath = "Registry::HKEY_CURRENT_USER\$($item.Path)"
            if (-not (Test-Path -LiteralPath $keyPath)) { New-Item -Path $keyPath -Force | Out-Null }
            $key = Get-Item -LiteralPath $keyPath
            try {
                if ($item.Exists) {
                    $kind = [Microsoft.Win32.RegistryValueKind]::$($item.Kind)
                    $key.SetValue([string]$item.Name, $item.Value, $kind)
                } else {
                    $key.DeleteValue([string]$item.Name, $false)
                }
            } finally { $key.Close() }
            Write-Log "Restored $($item.Path)\$($item.Name)"
        } catch { Write-Log "Restore failed for $($item.Name): $($_.Exception.Message)" }
    }
}

function Save-ServiceState([string]$Name) {
    if ($script:ChangedServices.ContainsKey($Name)) { return }
    $svc = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
    if (-not $svc) { throw "Service $Name was not found." }
    $script:ChangedServices[$Name] = [pscustomobject]@{ Name=$Name; StartMode=$svc.StartMode; State=$svc.State }
    @($script:ChangedServices.Values) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:ServiceBackup -Encoding UTF8
}

# Each entry is an actual per-user registry preference. No placeholder or fake "FPS" switches.
$script:Tweaks = @(
@{Id='GameMode';Name='Enable Windows Game Mode';Category='Gaming';Path='Software\Microsoft\GameBar';ValueName='AutoGameModeEnabled';Value=1;Kind='DWord';Description='Enables the Windows Game Mode preference.';Risk='Low'},
@{Id='GameMode2';Name='Allow automatic Game Mode';Category='Gaming';Path='Software\Microsoft\GameBar';ValueName='AllowAutoGameMode';Value=1;Kind='DWord';Description='Allows Windows to manage Game Mode automatically.';Risk='Low'},
@{Id='GameDVR';Name='Disable Game DVR capture';Category='Gaming';Path='System\GameConfigStore';ValueName='GameDVR_Enabled';Value=0;Kind='DWord';Description='Disables the current-user Game DVR capture preference.';Risk='Low'},
@{Id='GameDVR2';Name='Disable app capture';Category='Gaming';Path='Software\Microsoft\Windows\CurrentVersion\GameDVR';ValueName='AppCaptureEnabled';Value=0;Kind='DWord';Description='Disables Windows app capture preference for this user.';Risk='Low'},
@{Id='FullscreenOpt';Name='Disable fullscreen optimizations override';Category='Gaming';Path='System\GameConfigStore';ValueName='GameDVR_FSEBehaviorMode';Value=2;Kind='DWord';Description='Sets the per-user fullscreen behavior preference; game compatibility can vary.';Risk='Medium'},
@{Id='XboxGameBar';Name='Disable Xbox Game Bar presence writer';Category='Gaming';Path='Software\Microsoft\GameBar';ValueName='ShowStartupPanel';Value=0;Kind='DWord';Description='Hides the Game Bar startup panel. Does not uninstall Game Bar.';Risk='Low'},
@{Id='GameBarTips';Name='Disable Game Bar tips';Category='Gaming';Path='Software\Microsoft\GameBar';ValueName='UseNexusForGameBarEnabled';Value=0;Kind='DWord';Description='Turns off a Game Bar integration preference.';Risk='Low'},
@{Id='MouseSpeed';Name='Disable mouse acceleration';Category='Gaming';Path='Control Panel\Mouse';ValueName='MouseSpeed';Value='0';Kind='String';Description='Disables Windows pointer acceleration.';Risk='Low'},
@{Id='MouseThreshold1';Name='Disable mouse threshold 1';Category='Gaming';Path='Control Panel\Mouse';ValueName='MouseThreshold1';Value='0';Kind='String';Description='Sets the first mouse acceleration threshold to zero.';Risk='Low'},
@{Id='MouseThreshold2';Name='Disable mouse threshold 2';Category='Gaming';Path='Control Panel\Mouse';ValueName='MouseThreshold2';Value='0';Kind='String';Description='Sets the second mouse acceleration threshold to zero.';Risk='Low'},
@{Id='VisualFX';Name='Prefer performance visual effects';Category='Performance';Path='Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects';ValueName='VisualFXSetting';Value=2;Kind='DWord';Description='Selects the Windows visual-effects performance preset.';Risk='Low'},
@{Id='MenuDelay';Name='Reduce menu show delay';Category='Performance';Path='Control Panel\Desktop';ValueName='MenuShowDelay';Value='0';Kind='String';Description='Sets the menu animation delay to zero milliseconds.';Risk='Low'},
@{Id='MinAnimate';Name='Disable window minimize animation';Category='Performance';Path='Control Panel\Desktop\WindowMetrics';ValueName='MinAnimate';Value='0';Kind='String';Description='Disables the minimize/maximize animation preference.';Risk='Low'},
@{Id='TaskbarAnimations';Name='Disable taskbar animations';Category='Performance';Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';ValueName='TaskbarAnimations';Value=0;Kind='DWord';Description='Disables taskbar animation preference.';Risk='Low'},
@{Id='Transparency';Name='Disable transparency effects';Category='Performance';Path='Software\Microsoft\Windows\CurrentVersion\Themes\Personalize';ValueName='EnableTransparency';Value=0;Kind='DWord';Description='Disables Windows transparency effects for this user.';Risk='Low'},
@{Id='VisualFX2';Name='Disable animation effects';Category='Performance';Path='Software\Microsoft\Windows\CurrentVersion\Accessibility';ValueName='AnimationEffects';Value=0;Kind='DWord';Description='Turns off animation effects preference.';Risk='Low'},
@{Id='SmoothScroll';Name='Disable smooth scrolling preference';Category='Performance';Path='Control Panel\Desktop';ValueName='SmoothScroll';Value=0;Kind='DWord';Description='Sets the legacy smooth-scroll preference to off where honored.';Risk='Low'},
@{Id='BackgroundApps';Name='Disable background app global policy';Category='Privacy';Path='Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications';ValueName='GlobalUserDisabled';Value=1;Kind='DWord';Description='Restricts background app activity for this user; app behavior varies.';Risk='Medium'},
@{Id='Suggestions';Name='Disable Start app suggestions';Category='Privacy';Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager';ValueName='SystemPaneSuggestionsEnabled';Value=0;Kind='DWord';Description='Disables one Windows content suggestion preference.';Risk='Low'},
@{Id='SubscribedContent1';Name='Disable suggested content 338388';Category='Privacy';Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager';ValueName='SubscribedContent-338388Enabled';Value=0;Kind='DWord';Description='Disables a Windows consumer-content subscription.';Risk='Low'},
@{Id='SubscribedContent2';Name='Disable suggested content 353694';Category='Privacy';Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager';ValueName='SubscribedContent-353694Enabled';Value=0;Kind='DWord';Description='Disables a Windows consumer-content subscription.';Risk='Low'},
@{Id='SubscribedContent3';Name='Disable suggested content 353696';Category='Privacy';Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager';ValueName='SubscribedContent-353696Enabled';Value=0;Kind='DWord';Description='Disables a Windows consumer-content subscription.';Risk='Low'},
@{Id='SoftLanding';Name='Disable Windows tips';Category='Privacy';Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager';ValueName='SoftLandingEnabled';Value=0;Kind='DWord';Description='Disables Windows tips and suggestions preference.';Risk='Low'},
@{Id='RotatingLock';Name='Disable lock screen tips';Category='Privacy';Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager';ValueName='RotatingLockScreenOverlayEnabled';Value=0;Kind='DWord';Description='Disables lock-screen overlay suggestions.';Risk='Low'},
@{Id='AdvertisingId';Name='Disable advertising ID';Category='Privacy';Path='Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo';ValueName='Enabled';Value=0;Kind='DWord';Description='Disables the advertising ID preference for this user.';Risk='Low'},
@{Id='Tailored';Name='Disable tailored experiences';Category='Privacy';Path='Software\Microsoft\Windows\CurrentVersion\Privacy';ValueName='TailoredExperiencesWithDiagnosticDataEnabled';Value=0;Kind='DWord';Description='Opts out of tailored experiences based on diagnostic data.';Risk='Low'},
@{Id='Feedback';Name='Set feedback frequency to never';Category='Privacy';Path='Software\Microsoft\Siuf\Rules';ValueName='NumberOfSIUFInPeriod';Value=0;Kind='DWord';Description='Sets the current-user feedback frequency preference.';Risk='Low'},
@{Id='SearchHighlights';Name='Disable search highlights';Category='Privacy';Path='Software\Microsoft\Windows\CurrentVersion\SearchSettings';ValueName='IsDynamicSearchBoxEnabled';Value=0;Kind='DWord';Description='Disables dynamic search box suggestions where supported.';Risk='Low'},
@{Id='BingSearch';Name='Disable web search suggestions in Start';Category='Privacy';Path='Software\Policies\Microsoft\Windows\Explorer';ValueName='DisableSearchBoxSuggestions';Value=1;Kind='DWord';Description='Applies a per-user policy to hide web suggestions in search.';Risk='Medium'},
@{Id='ClipboardHistory';Name='Disable clipboard history';Category='Privacy';Path='Software\Microsoft\Clipboard';ValueName='EnableClipboardHistory';Value=0;Kind='DWord';Description='Disables clipboard history; normal copy/paste remains.';Risk='Low'},
@{Id='ActivityFeed';Name='Disable activity feed publishing';Category='Privacy';Path='Software\Policies\Microsoft\Windows\System';ValueName='EnableActivityFeed';Value=0;Kind='DWord';Description='Disables the activity feed policy for this user.';Risk='Medium'},
@{Id='Location';Name='Disable user location consent';Category='Privacy';Path='Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location';ValueName='Value';Value='Deny';Kind='String';Description='Denies location access through the user consent store; may affect apps.';Risk='Medium'},
@{Id='Camera';Name='Disable camera app consent';Category='Privacy';Path='Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam';ValueName='Value';Value='Deny';Kind='String';Description='Denies camera access through the user consent store.';Risk='Medium'},
@{Id='Microphone';Name='Disable microphone app consent';Category='Privacy';Path='Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone';ValueName='Value';Value='Deny';Kind='String';Description='Denies microphone access through the user consent store.';Risk='Medium'},
@{Id='Autoplay';Name='Disable AutoPlay';Category='Explorer';Path='Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers';ValueName='DisableAutoplay';Value=1;Kind='DWord';Description='Disables AutoPlay for the current user.';Risk='Low'},
@{Id='FileExt';Name='Show file extensions';Category='Explorer';Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';ValueName='HideFileExt';Value=0;Kind='DWord';Description='Shows known file extensions in File Explorer.';Risk='Low'},
@{Id='HiddenFiles';Name='Show hidden files';Category='Explorer';Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';ValueName='Hidden';Value=1;Kind='DWord';Description='Shows hidden files in File Explorer.';Risk='Low'},
@{Id='SuperHidden';Name='Show protected operating system files';Category='Explorer';Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';ValueName='ShowSuperHidden';Value=1;Kind='DWord';Description='Shows protected OS files; use caution when browsing system folders.';Risk='Medium'},
@{Id='LaunchTo';Name='Open File Explorer to This PC';Category='Explorer';Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';ValueName='LaunchTo';Value=1;Kind='DWord';Description='Sets File Explorer default landing page to This PC.';Risk='Low'},
@{Id='TaskbarSearch';Name='Hide taskbar search box';Category='Explorer';Path='Software\Microsoft\Windows\CurrentVersion\Search';ValueName='SearchboxTaskbarMode';Value=0;Kind='DWord';Description='Hides the taskbar search box on supported Windows builds.';Risk='Low'},
@{Id='TaskView';Name='Hide Task View button';Category='Explorer';Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';ValueName='ShowTaskViewButton';Value=0;Kind='DWord';Description='Hides the Task View button.';Risk='Low'},
@{Id='Widgets';Name='Hide taskbar Widgets button';Category='Explorer';Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';ValueName='TaskbarDa';Value=0;Kind='DWord';Description='Hides the Widgets button on supported Windows builds.';Risk='Low'},
@{Id='Chat';Name='Hide Chat taskbar button';Category='Explorer';Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';ValueName='TaskbarMn';Value=0;Kind='DWord';Description='Hides the legacy Chat taskbar button where present.';Risk='Low'},
@{Id='SnapAssist';Name='Disable Snap Assist flyout';Category='Explorer';Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';ValueName='SnapAssist';Value=0;Kind='DWord';Description='Disables the Snap Assist preference.';Risk='Low'},
@{Id='FileSync';Name='Disable sync provider notifications';Category='Explorer';Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';ValueName='ShowSyncProviderNotifications';Value=0;Kind='DWord';Description='Hides sync-provider notifications in Explorer.';Risk='Low'},
@{Id='SeparateProcess';Name='Launch folder windows in separate process';Category='Explorer';Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';ValueName='SeparateProcess';Value=1;Kind='DWord';Description='Runs folder windows in a separate Explorer process; uses extra memory.';Risk='Medium'},
@{Id='VerboseStatus';Name='Show detailed shutdown messages';Category='System';Path='Software\Microsoft\Windows\CurrentVersion\Policies\System';ValueName='VerboseStatus';Value=1;Kind='DWord';Description='Shows additional status messages during sign-in and shutdown.';Risk='Low'},
@{Id='DisableNLA';Name='Keep network location awareness default';Category='Network';Path='Software\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles';ValueName='Category';Value=0;Kind='DWord';Description='Not applied automatically: network profile category is per-profile and should be configured in Settings.';Risk='Low';Disabled=$true},
@{Id='EdgeStartup';Name='Disable Edge startup boost preference';Category='Performance';Path='Software\Policies\Microsoft\Edge';ValueName='StartupBoostEnabled';Value=0;Kind='DWord';Description='Sets the Edge policy to disable Startup Boost for managed Edge installs.';Risk='Medium'},
@{Id='EdgeBackground';Name='Disable Edge background mode';Category='Performance';Path='Software\Policies\Microsoft\Edge';ValueName='BackgroundModeEnabled';Value=0;Kind='DWord';Description='Sets the Edge policy to prevent background apps after Edge closes.';Risk='Medium'},
@{Id='OfficeTelemetry';Name='Disable Office telemetry opt-in';Category='Privacy';Path='Software\Policies\Microsoft\Office\16.0\Common';ValueName='TelemetryOptIn';Value=0;Kind='DWord';Description='Sets an Office policy where supported; has no effect if Office is absent.';Risk='Medium'},
@{Id='OneDriveFiles';Name='Disable OneDrive file sync prompts';Category='Explorer';Path='Software\Microsoft\OneDrive';ValueName='DisableTutorial';Value=1;Kind='DWord';Description='Disables the OneDrive first-run tutorial preference.';Risk='Low'},
@{Id='PrintNotifications';Name='Hide printer notification messages';Category='System';Path='Software\Microsoft\Windows NT\CurrentVersion\Print\Providers\Client Side Rendering Print Provider';ValueName='DisableHTTPPrinting';Value=1;Kind='DWord';Description='Disables HTTP printing provider preference; may affect unusual printer workflows.';Risk='Medium'},
@{Id='DeliveryOptimization';Name='Limit peer delivery downloads';Category='Updates';Path='Software\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings';ValueName='DownloadMode';Value=0;Kind='DWord';Description='Sets Delivery Optimization download mode to HTTP-only for this user.';Risk='Low'},
@{Id='ActiveHours';Name='Set Windows active hours start';Category='Updates';Path='Software\Microsoft\WindowsUpdate\UX\Settings';ValueName='ActiveHoursStart';Value=8;Kind='DWord';Description='Sets active hours start to 8:00 where the Windows Update UI honors it.';Risk='Low'},
@{Id='ActiveHoursEnd';Name='Set Windows active hours end';Category='Updates';Path='Software\Microsoft\WindowsUpdate\UX\Settings';ValueName='ActiveHoursEnd';Value=23;Kind='DWord';Description='Sets active hours end to 23:00 where the Windows Update UI honors it.';Risk='Low'},
@{Id='RestartNotify';Name='Disable restart notifications during active hours';Category='Updates';Path='Software\Microsoft\WindowsUpdate\UX\Settings';ValueName='RestartNotificationsAllowed2';Value=0;Kind='DWord';Description='Changes update restart notification preference; Windows may override it.';Risk='Medium'},
@{Id='StorageSense';Name='Enable Storage Sense';Category='Storage';Path='Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy';ValueName='01';Value=1;Kind='DWord';Description='Enables Storage Sense preference. Review cleanup behavior in Settings.';Risk='Low'},
@{Id='RecycleBin';Name='Set Recycle Bin delete confirmation';Category='Storage';Path='Software\Microsoft\Windows\CurrentVersion\Policies\Explorer';ValueName='ConfirmFileDelete';Value=1;Kind='DWord';Description='Prompts before deleting files to the Recycle Bin.';Risk='Low'},
@{Id='RecentDocs';Name='Disable recent documents tracking';Category='Privacy';Path='Software\Microsoft\Windows\CurrentVersion\Policies\Explorer';ValueName='NoRecentDocsHistory';Value=1;Kind='DWord';Description='Disables recent document history in supported shell locations.';Risk='Low'},
@{Id='RecentJumplists';Name='Do not keep history of recently opened documents';Category='Privacy';Path='Software\Microsoft\Windows\CurrentVersion\Policies\Explorer';ValueName='NoRecentDocsNetHood';Value=1;Kind='DWord';Description='Disables a recent-documents history policy.';Risk='Low'},
@{Id='LockScreen';Name='Disable lock screen app notifications';Category='Privacy';Path='Software\Microsoft\Windows\CurrentVersion\Notifications\Settings';ValueName='NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK';Value=0;Kind='DWord';Description='Disables toast notifications above the lock screen.';Risk='Low'},
@{Id='Toast';Name='Disable notification toast banners';Category='Privacy';Path='Software\Microsoft\Windows\CurrentVersion\PushNotifications';ValueName='ToastEnabled';Value=0;Kind='DWord';Description='Disables toast notification preference for this user.';Risk='Medium'},
@{Id='CapsLock';Name='Turn off Caps Lock indicator behavior';Category='System';Path='Control Panel\Accessibility\Keyboard Response';ValueName='Flags';Value='122';Kind='String';Description='Sets a keyboard accessibility flags value; leave unchanged if you use Filter Keys.';Risk='Medium'},
@{Id='NumLock';Name='Enable Num Lock at sign-in';Category='System';Path='Control Panel\Keyboard';ValueName='InitialKeyboardIndicators';Value='2';Kind='String';Description='Requests Num Lock enabled at sign-in; firmware can override it.';Risk='Low'},
@{Id='AutoEndTasks';Name='Shorten app close wait preference';Category='Performance';Path='Control Panel\Desktop';ValueName='AutoEndTasks';Value='1';Kind='String';Description='Allows Windows to end nonresponsive user apps more quickly at shutdown.';Risk='Medium'},
@{Id='HungAppTimeout';Name='Set hung app timeout to 3 seconds';Category='Performance';Path='Control Panel\Desktop';ValueName='HungAppTimeout';Value='3000';Kind='String';Description='Changes shutdown wait behavior; does not improve game FPS.';Risk='Medium'},
@{Id='WaitToKill';Name='Set app shutdown wait to 3 seconds';Category='Performance';Path='Control Panel\Desktop';ValueName='WaitToKillAppTimeout';Value='3000';Kind='String';Description='Changes shutdown wait behavior; may cause unsaved work to be lost.';Risk='Medium'}
)

# Normalize the display model; exclude the one intentionally disabled informational item.
$script:Tweaks = @($script:Tweaks | Where-Object { -not $_.Disabled } | ForEach-Object {
    [pscustomobject]@{
        Id=$_.Id; Name=$_.Name; Category=$_.Category; Path=$_.Path
        NameValue=$_.ValueName; Value=$_.Value; Kind=$_.Kind
        Description=$_.Description; Risk=$_.Risk
    }
})

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Solar Tweaking Util" Width="1240" Height="790" MinWidth="1050" MinHeight="650" WindowStartupLocation="CenterScreen" Background="#101018" Foreground="#F3EFFA">
 <Window.Resources>
  <SolidColorBrush x:Key="Panel" Color="#1B1726"/><SolidColorBrush x:Key="Panel2" Color="#241D32"/><SolidColorBrush x:Key="Purple" Color="#8B50D6"/><SolidColorBrush x:Key="Muted" Color="#B9ADC9"/>
  <Style TargetType="Button"><Setter Property="Background" Value="#332744"/><Setter Property="Foreground" Value="#F6F0FF"/><Setter Property="BorderBrush" Value="#594276"/><Setter Property="Padding" Value="12,7"/><Setter Property="Margin" Value="3"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Cursor" Value="Hand"/></Style>
  <Style TargetType="TextBox"><Setter Property="Background" Value="#15111F"/><Setter Property="Foreground" Value="#F3EFFA"/><Setter Property="BorderBrush" Value="#594276"/><Setter Property="Padding" Value="8"/></Style>
  <Style TargetType="CheckBox"><Setter Property="Foreground" Value="#F3EFFA"/><Setter Property="Margin" Value="4,6"/><Setter Property="FontSize" Value="13"/></Style>
  <Style TargetType="ListBoxItem"><Setter Property="Padding" Value="8,6"/><Setter Property="Margin" Value="2"/><Setter Property="Foreground" Value="#EEE7FA"/></Style>
 </Window.Resources>
 <DockPanel>
  <Border DockPanel.Dock="Top" Background="#1D172A" Padding="12">
   <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
    <StackPanel Orientation="Horizontal"><Border Background="#8247C8" CornerRadius="7" Width="42" Height="42" Margin="0,0,12,0"><TextBlock Text="S" FontSize="29" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><StackPanel><TextBlock Text="SOLAR TWEAKING UTIL" FontSize="20" FontWeight="Bold"/><TextBlock Text="WINDOWS 11 • PERFORMANCE • DEBLOAT • CONTROL" FontSize="10" Foreground="#BBA8D8"/></StackPanel></StackPanel>
    <TextBlock Grid.Column="1" Text="ADMINISTRATOR  •  REVERSIBLE REGISTRY PROFILE" Foreground="#C7A5FF" VerticalAlignment="Center" FontSize="11"/>
   </Grid>
  </Border>
  <Border DockPanel.Dock="Bottom" Background="#1D172A" Padding="8">
   <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
    <TextBlock x:Name="StatusText" Text="Ready. Select actions to apply." Foreground="#CBBDE0" VerticalAlignment="Center" Margin="6"/>
    <Button x:Name="ApplyButton" Grid.Column="1" Content="APPLY SELECTED" Background="#7040B4" MinWidth="145"/>
    <Button x:Name="RestoreButton" Grid.Column="2" Content="RESTORE SESSION" MinWidth="145"/>
    <Button x:Name="AuditButton" Grid.Column="3" Content="SYSTEM AUDIT" MinWidth="120"/>
   </Grid>
  </Border>
  <Grid Margin="10">
   <Grid.ColumnDefinitions><ColumnDefinition Width="178"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
   <Border Background="{StaticResource Panel}" CornerRadius="9" Padding="9" Margin="0,0,9,0">
    <DockPanel>
     <StackPanel DockPanel.Dock="Top">
      <TextBlock Text="WORKSPACE" Foreground="#B99AE5" FontSize="11" FontWeight="Bold" Margin="4,8"/>
      <ListBox x:Name="Categories" Background="Transparent" BorderThickness="0">
       <ListBoxItem Content="All Tweaks" IsSelected="True"/><ListBoxItem Content="Gaming"/><ListBoxItem Content="Explorer"/><ListBoxItem Content="Privacy"/><ListBoxItem Content="Performance"/><ListBoxItem Content="Updates"/><ListBoxItem Content="Storage"/><ListBoxItem Content="System"/>
      </ListBox>
      <Separator Margin="3,10" Background="#514064"/>
      <Button x:Name="SelectVisible" Content="SELECT VISIBLE"/>
      <Button x:Name="ClearSelection" Content="CLEAR SELECTION"/>
      <Button x:Name="PresetStandard" Content="STANDARD PRESET"/>
      <Button x:Name="PresetGaming" Content="GAMING PRESET"/>
      <Button x:Name="PresetPrivacy" Content="PRIVACY PRESET"/>
     </StackPanel>
     <TextBlock DockPanel.Dock="Bottom" Text="Solar • Independent build" Foreground="#8E819F" FontSize="10" Margin="4,10"/>
    </DockPanel>
   </Border>
   <Grid Grid.Column="1">
    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="110"/></Grid.RowDefinitions>
    <Grid Margin="2,0,2,8">
     <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="290"/></Grid.ColumnDefinitions>
     <StackPanel><TextBlock x:Name="PageTitle" Text="All Tweaks" FontSize="21" FontWeight="Bold"/><TextBlock x:Name="CountText" Text="Loading actions..." Foreground="#C4B5D8" FontSize="11"/></StackPanel>
     <TextBox x:Name="SearchBox" Grid.Column="1" Height="34" VerticalContentAlignment="Center" ToolTip="Search tweaks by name, category, or description"/>
    </Grid>
    <Border Grid.Row="1" Background="{StaticResource Panel}" CornerRadius="9" Padding="8">
     <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="270"/></Grid.ColumnDefinitions>
      <ListView x:Name="TweakList" Background="Transparent" BorderThickness="0" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
       <ListView.ItemTemplate><DataTemplate>
        <Border Background="#241D32" CornerRadius="6" Padding="8" Margin="2">
         <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="28"/><ColumnDefinition Width="*"/><ColumnDefinition Width="75"/></Grid.ColumnDefinitions>
          <CheckBox IsChecked="{Binding Selected, Mode=TwoWay}" VerticalAlignment="Center"/>
          <StackPanel Grid.Column="1"><TextBlock Text="{Binding Name}" FontWeight="SemiBold" Foreground="#F6F0FC"/><TextBlock Text="{Binding Summary}" Foreground="#BBAED0" FontSize="10" TextTrimming="CharacterEllipsis"/></StackPanel>
          <TextBlock Grid.Column="2" Text="{Binding Risk}" Foreground="#C5A1F5" FontSize="10" VerticalAlignment="Center" HorizontalAlignment="Right"/>
         </Grid>
        </Border>
       </DataTemplate></ListView.ItemTemplate>
      </ListView>
      <Border Grid.Column="1" Background="#211A2D" CornerRadius="7" Padding="12" Margin="8,0,0,0">
       <StackPanel>
        <TextBlock Text="ACTION DETAILS" Foreground="#C7A5FF" FontWeight="Bold" FontSize="13"/>
        <TextBlock x:Name="DetailName" Text="Select an action" FontWeight="Bold" Margin="0,12,0,5" TextWrapping="Wrap"/>
        <TextBlock x:Name="DetailCategory" Foreground="#BCA8D5" FontSize="10"/>
        <TextBlock x:Name="DetailDescription" Foreground="#D5CDE0" TextWrapping="Wrap" Margin="0,12,0,10"/>
        <TextBlock Text="Risk level" Foreground="#A99AB9" FontSize="10"/>
        <TextBlock x:Name="DetailRisk" Foreground="#C7A5FF" FontWeight="SemiBold" Margin="0,3,0,10"/>
        <Separator Background="#514064"/>
        <TextBlock Text="Backups are created before each registry change. Restore Session reverses changes made by this run. Some Windows preferences may require sign-out or restart." Foreground="#AFA3BE" FontSize="10" TextWrapping="Wrap" Margin="0,10,0,0"/>
       </StackPanel>
      </Border>
     </Grid>
    </Border>
    <Border Grid.Row="2" Background="{StaticResource Panel}" CornerRadius="9" Padding="10" Margin="0,8,0,0">
     <DockPanel><TextBlock DockPanel.Dock="Top" Text="EXECUTION LOG" Foreground="#C7A5FF" FontWeight="Bold" FontSize="11" Margin="0,0,0,5"/><TextBox x:Name="LogBox" Background="#15111F" BorderThickness="0" IsReadOnly="True" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" FontSize="10" FontFamily="Consolas"/></DockPanel>
    </Border>
   </Grid>
  </Grid>
 </DockPanel>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
foreach ($n in @('StatusText','LogBox')) { Set-Variable -Scope Script -Name $n -Value $window.FindName($n) }
$script:StatusText = $window.FindName('StatusText')
$script:LogBox = $window.FindName('LogBox')
$list = $window.FindName('TweakList')
$categoryList = $window.FindName('Categories')
$search = $window.FindName('SearchBox')
$allRows = @($script:Tweaks | ForEach-Object {
    [pscustomobject]@{
        Id=$_.Id; Name=$_.Name; Category=$_.Category; Path=$_.Path
        ValueName=$_.NameValue; Value=$_.Value; Kind=$_.Kind
        Description=$_.Description; Risk=$_.Risk; Selected=$false
        Summary=("$($_.Category) • $($_.Description)")
    }
})
$view = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
function Refresh-List {
    $view.Clear()
    $cat = [string]$categoryList.SelectedItem.Content
    $term = $search.Text.Trim()
    foreach ($row in $allRows) {
        $categoryMatch = ($cat -eq 'All Tweaks' -or $row.Category -eq $cat)
        $searchMatch = ([string]::IsNullOrWhiteSpace($term) -or
            $row.Name.IndexOf($term,[StringComparison]::OrdinalIgnoreCase) -ge 0 -or
            $row.Description.IndexOf($term,[StringComparison]::OrdinalIgnoreCase) -ge 0 -or
            $row.Category.IndexOf($term,[StringComparison]::OrdinalIgnoreCase) -ge 0)
        if ($categoryMatch -and $searchMatch) { $view.Add($row) }
    }
    $list.ItemsSource = $null
    $list.ItemsSource = $view
    $window.FindName('PageTitle').Text = $cat
    $window.FindName('CountText').Text = "$($view.Count) visible • $($allRows.Count) available actions • backed-up registry preferences"
}
Refresh-List
$categoryList.Add_SelectionChanged({ Refresh-List })
$search.Add_TextChanged({ Refresh-List })
$list.Add_SelectionChanged({
    $row = $list.SelectedItem
    if ($row) {
        $window.FindName('DetailName').Text = $row.Name
        $window.FindName('DetailCategory').Text = "$($row.Category)  •  $($row.Id)"
        $window.FindName('DetailDescription').Text = $row.Description
        $window.FindName('DetailRisk').Text = $row.Risk
    }
})
$window.FindName('SelectVisible').Add_Click({ foreach ($row in $view) { $row.Selected=$true }; $list.Items.Refresh() })
$window.FindName('ClearSelection').Add_Click({ foreach ($row in $allRows) { $row.Selected=$false }; $list.Items.Refresh() })
$window.FindName('PresetStandard').Add_Click({
    foreach ($row in $allRows) { $row.Selected = ($row.Id -in @('GameMode','GameMode2','GameDVR','GameDVR2','MouseSpeed','MouseThreshold1','MouseThreshold2','FileExt','HiddenFiles')) }
    $list.Items.Refresh(); Write-Log 'Standard preset selected. Nothing applied yet.'
})
$window.FindName('PresetGaming').Add_Click({
    foreach ($row in $allRows) { $row.Selected = ($row.Category -eq 'Gaming' -or $row.Id -in @('VisualFX','MenuDelay','TaskbarAnimations','Transparency')) }
    $list.Items.Refresh(); Write-Log 'Gaming preset selected. Nothing applied yet.'
})
$window.FindName('PresetPrivacy').Add_Click({
    foreach ($row in $allRows) { $row.Selected = ($row.Category -eq 'Privacy') }
    $list.Items.Refresh(); Write-Log 'Privacy preset selected. Nothing applied yet.'
})
$window.FindName('ApplyButton').Add_Click({
    $chosen = @($allRows | Where-Object Selected)
    if ($chosen.Count -eq 0) { [System.Windows.MessageBox]::Show('Select at least one action first.','Solar') | Out-Null; return }
    $names = ($chosen | ForEach-Object Name) -join "`n"
    if ([System.Windows.MessageBox]::Show("Apply $($chosen.Count) selected registry preferences?`n`n$names`n`nA backup is saved before each value is changed.",'Confirm Solar Tweaks','YesNo','Warning') -ne 'Yes') { return }
    foreach ($tweak in $chosen) {
        try {
            $applyObject = [pscustomobject]@{ Path=$tweak.Path; Name=$tweak.ValueName; Value=$tweak.Value; Kind=$tweak.Kind }
            Set-SolarRegistryValue $applyObject
            Write-Log "Applied: $($tweak.Name)"
        } catch { Write-Log "FAILED: $($tweak.Name) — $($_.Exception.Message)" }
    }
    Write-Log "Apply run finished. Backup: $script:SessionBackup"
})
$window.FindName('RestoreButton').Add_Click({
    if ([System.Windows.MessageBox]::Show("Restore registry values changed during this session?`n`n$script:SessionBackup",'Confirm Restore','YesNo','Warning') -ne 'Yes') { return }
    Restore-RegistryBackup -File $script:BackupFile
    Write-Log 'Session registry restore finished.'
})
$window.FindName('AuditButton').Add_Click({
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $ram = [math]::Round($os.TotalVisibleMemorySize/1MB,1)
    Write-Log "AUDIT: $($os.Caption) build $($os.BuildNumber) | CPU: $($cpu.Name) | GPU: $($gpu.Name) | RAM: $ram GB"
    Write-Log "Power plan: $((powercfg /getactivescheme) -join ' ')"
})
Write-Log "Solar started. $($allRows.Count) actual registry preference actions loaded."
$null = $window.ShowDialog()