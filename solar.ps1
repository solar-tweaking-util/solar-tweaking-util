# Solar Tweaking Util - WPF starter
# Run elevated. Preserves Defender, Bluetooth, Windows Update, Store, Gaming Services and drivers.
# App removals and temp cleanup are not fully reversible.
#Requires -Version 5.1
$ErrorActionPreference='Stop'
function IsAdmin {
 $p=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
 return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if(-not (IsAdmin)){Add-Type -AssemblyName PresentationFramework;[System.Windows.MessageBox]::Show('Run PowerShell as Administrator.','Solar Tweaking Util')|Out-Null;return}
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$root=Join-Path $env:ProgramData 'SolarTweakingUtil';New-Item $root -ItemType Directory -Force|Out-Null
$backup=Join-Path $root ('Backup-'+(Get-Date -Format 'yyyyMMdd-HHmmss'));New-Item $backup -ItemType Directory -Force|Out-Null
$regfile=Join-Path $backup 'registry.jsonl';$logfile=Join-Path $root 'Solar.log';$logbox=$null
function Log([string]$m){$line=('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'),$m);Add-Content $logfile $line;if($logbox){$logbox.AppendText($line+[Environment]::NewLine);$logbox.ScrollToEnd()}}
function SetDword([string]$path,[string]$name,[int]$value){
 $key="HKCU:\$path";if(!(Test-Path $key)){New-Item $key -Force|Out-Null}
 $props=Get-ItemProperty $key -ErrorAction SilentlyContinue;$present=$null -ne $props -and $props.PSObject.Properties.Name -contains $name
 $old=if($present){$props.$name}else{$null}
 $seen=Select-String -Path $regfile -SimpleMatch ('"Name":"'+$name+'"') -Quiet -ErrorAction SilentlyContinue
 if(!$seen){[pscustomobject]@{Path=$path;Name=$name;Present=$present;Value=$old;Kind='DWord'}|ConvertTo-Json -Compress|Add-Content $regfile}
 New-ItemProperty $key $name $value -PropertyType DWord -Force|Out-Null
}
function Apply([string]$id){
 switch($id){
 'GameMode'{SetDword 'Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1;SetDword 'Software\Microsoft\GameBar' 'AllowAutoGameMode' 1;Log 'Game Mode preferences enabled.'}
 'GameDVR'{SetDword 'System\GameConfigStore' 'GameDVR_Enabled' 0;SetDword 'Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0;Log 'Game DVR capture preferences disabled.'}
 'BackgroundApps'{SetDword 'Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1;Log 'Background app activity restricted.'}
 'Transparency'{SetDword 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0;Log 'Transparency disabled.'}
 'MouseAccel'{$k='HKCU:\Control Panel\Mouse';$v=Get-ItemProperty $k;foreach($n in 'MouseSpeed','MouseThreshold1','MouseThreshold2'){$seen=Select-String $regfile -SimpleMatch ('"Name":"'+$n+'"') -Quiet -ErrorAction SilentlyContinue;if(!$seen){[pscustomobject]@{Path='Control Panel\Mouse';Name=$n;Present=$true;Value=$v.$n;Kind='String'}|ConvertTo-Json -Compress|Add-Content $regfile}};Set-ItemProperty $k MouseSpeed '0';Set-ItemProperty $k MouseThreshold1 '0';Set-ItemProperty $k MouseThreshold2 '0';Log 'Mouse acceleration disabled.'}
 'PowerPlan'{$old=powercfg /getactivescheme|Out-String;Set-Content (Join-Path $backup 'power-plan.txt') $old;$hp=powercfg /list|Select-String 'High performance'|Select-Object -First 1;if($hp -and $hp.ToString() -match '[0-9a-fA-F-]{36}'){powercfg /setactive $Matches[0];Log 'High Performance plan selected.'}else{Log 'High Performance plan unavailable; no change.'}}
 'Hibernation'{powercfg /hibernate off;Log 'Hibernation disabled. Restore with powercfg /hibernate on.'}
 'Telemetry'{$svc=Get-CimInstance Win32_Service -Filter "Name='DiagTrack'" -ErrorAction SilentlyContinue;if($svc){[pscustomobject]@{Name='DiagTrack';StartMode=$svc.StartMode;State=$svc.State}|ConvertTo-Json -Compress|Add-Content (Join-Path $backup 'services.jsonl');Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue;Set-Service DiagTrack -StartupType Disabled;Log 'DiagTrack disabled.'}else{Log 'DiagTrack not found.'}}
 'TempCleanup'{foreach($p in @($env:TEMP,(Join-Path $env:WINDIR 'Temp'))){if(Test-Path $p){Get-ChildItem $p -Force -ErrorAction SilentlyContinue|Remove-Item -Recurse -Force -ErrorAction SilentlyContinue}};Log 'Accessible temp files removed.'}
 'XboxApps'{foreach($n in @('Microsoft.XboxApp','Microsoft.XboxGamingOverlay','Microsoft.Xbox.TCUI','Microsoft.XboxSpeechToTextOverlay')){Get-AppxPackage -AllUsers -Name $n -ErrorAction SilentlyContinue|ForEach-Object{Log ('Removing '+$_.Name);Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Continue};Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue|Where-Object DisplayName -eq $n|Remove-AppxProvisionedPackage -Online -ErrorAction Continue|Out-Null};Log 'Xbox consumer apps processed; Store and Gaming Services preserved.'}
 }
}
function Restore{
 if(Test-Path $regfile){foreach($line in Get-Content $regfile){try{$v=$line|ConvertFrom-Json;$k="HKCU:\$($v.Path)";if(!(Test-Path $k)){New-Item $k -Force|Out-Null};if($v.Present){if($v.Kind -eq 'String'){Set-ItemProperty $k $v.Name ([string]$v.Value)}else{New-ItemProperty $k $v.Name ([int]$v.Value) -PropertyType DWord -Force|Out-Null}}else{Remove-ItemProperty $k $v.Name -ErrorAction SilentlyContinue}}catch{Log ('Restore warning: '+$_.Exception.Message)}}}
 $sf=Join-Path $backup 'services.jsonl';if(Test-Path $sf){foreach($line in Get-Content $sf){try{$v=$line|ConvertFrom-Json;if($v.StartMode -eq 'Auto'){Set-Service $v.Name -StartupType Automatic}elseif($v.StartMode -eq 'Manual'){Set-Service $v.Name -StartupType Manual}elseif($v.StartMode -eq 'Disabled'){Set-Service $v.Name -StartupType Disabled};if($v.State -eq 'Running'){Start-Service $v.Name -ErrorAction SilentlyContinue}}catch{}}}
 $pf=Join-Path $backup 'power-plan.txt';if(Test-Path $pf){$m=Select-String $pf -Pattern '[0-9a-fA-F-]{36}'|Select-Object -First 1;if($m){powercfg /setactive $m.Matches[0].Value}}
 Log 'Restore completed. AppX removal, temp cleanup and hibernation require manual reversal.'
}
[xml]$x=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Solar Tweaking Util" Height="760" Width="1260" MinHeight="640" MinWidth="980" WindowStartupLocation="CenterScreen" Background="#17121F" Foreground="#F2ECFA">
<Window.Resources><Style TargetType="Button"><Setter Property="Background" Value="#30243F"/><Setter Property="Foreground" Value="#F5F0FC"/><Setter Property="BorderBrush" Value="#7653A0"/><Setter Property="Padding" Value="12,7"/><Setter Property="Margin" Value="3"/><Setter Property="Cursor" Value="Hand"/></Style><Style TargetType="CheckBox"><Setter Property="Foreground" Value="#EEE7F8"/><Setter Property="Margin" Value="5"/><Setter Property="FontSize" Value="13"/></Style><Style TargetType="TabItem"><Setter Property="Foreground" Value="#F5F0FC"/><Setter Property="Background" Value="#30243F"/><Setter Property="Padding" Value="18,9"/><Setter Property="Margin" Value="3"/></Style></Window.Resources>
<DockPanel><Border DockPanel.Dock="Top" Background="#21162F" Padding="12"><StackPanel Orientation="Horizontal"><Border Background="#8754D6" CornerRadius="8" Width="42" Height="42" Margin="0,0,10,0"><TextBlock Text="S" FontSize="28" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><StackPanel><TextBlock Text="SOLAR TWEAKING UTIL" FontSize="20" FontWeight="Bold"/><TextBlock Text="Windows 11 Gaming Optimizer" Foreground="#BFA8E2" FontSize="11"/></StackPanel></StackPanel></Border>
<Border DockPanel.Dock="Bottom" Background="#21162F" Padding="7"><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBlock x:Name="Status" Text="Ready — select tweaks, then Run Selected." VerticalAlignment="Center" Foreground="#CBB9E8" Margin="8"/><Button x:Name="Run" Grid.Column="1" Content="RUN SELECTED TWEAKS" Background="#7040B7" MinWidth="190"/><Button x:Name="Undo" Grid.Column="2" Content="UNDO / RESTORE" MinWidth="150"/></Grid></Border>
<TabControl Background="#17121F" BorderBrush="#49375F">
<TabItem Header="Tweaks"><Grid Margin="10"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions><WrapPanel><Button x:Name="Standard" Content="Standard"/><Button x:Name="Minimal" Content="Minimal"/><Button x:Name="Advanced" Content="Advanced"/><Button x:Name="Clear" Content="Clear"/><Button x:Name="SelectAll" Content="Select All"/></WrapPanel><Grid Grid.Row="1"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
<Border Background="#211A2C" CornerRadius="7" Padding="12" Margin="3"><ScrollViewer><StackPanel><TextBlock Text="ESSENTIAL TWEAKS" Foreground="#B995F1" FontSize="16" FontFamily="Consolas"/>
<CheckBox x:Name="GameMode" Tag="GameMode" Content="Enable Windows Game Mode"/><CheckBox x:Name="GameDVR" Tag="GameDVR" Content="Disable Game DVR / background capture"/><CheckBox x:Name="BackgroundApps" Tag="BackgroundApps" Content="Restrict background apps"/><CheckBox x:Name="Transparency" Tag="Transparency" Content="Disable transparency effects"/><CheckBox x:Name="MouseAccel" Tag="MouseAccel" Content="Disable mouse acceleration"/><CheckBox x:Name="PowerPlan" Tag="PowerPlan" Content="Select High Performance power plan"/><CheckBox x:Name="TempCleanup" Tag="TempCleanup" Content="Clean temporary files"/>
<TextBlock Text="ADVANCED / OPTIONAL" Foreground="#B995F1" FontSize="16" FontFamily="Consolas" Margin="0,16,0,0"/><CheckBox x:Name="Hibernation" Tag="Hibernation" Content="Disable hibernation"/><CheckBox x:Name="Telemetry" Tag="Telemetry" Content="Disable DiagTrack telemetry service"/><CheckBox x:Name="XboxApps" Tag="XboxApps" Content="Remove Xbox consumer apps (keep Store)"/><TextBlock Text="Protected: Defender, Bluetooth, Windows Update, Microsoft Store, Gaming Services and essential drivers." TextWrapping="Wrap" Foreground="#9FE3B0" Margin="4,16,4,4"/></StackPanel></ScrollViewer></Border>
<Border Grid.Column="1" Background="#211A2C" CornerRadius="7" Padding="14" Margin="3"><StackPanel><TextBlock Text="CUSTOMIZE PREFERENCES" Foreground="#B995F1" FontSize="16" FontFamily="Consolas"/><TextBlock Text="Choose a preset or individual actions. Review the confirmation before applying." TextWrapping="Wrap" Foreground="#C8BED5" Margin="0,10,0,14"/><Border Background="#2A2138" CornerRadius="6" Padding="12" Margin="0,0,0,8"><StackPanel><TextBlock Text="STANDARD" FontWeight="Bold"/><TextBlock Text="Game Mode, Game DVR, transparency and mouse settings." Foreground="#C8BED5" TextWrapping="Wrap"/></StackPanel></Border><Border Background="#2A2138" CornerRadius="6" Padding="12" Margin="0,0,0,8"><StackPanel><TextBlock Text="MINIMAL" FontWeight="Bold"/><TextBlock Text="Only basic gaming preference tweaks." Foreground="#C8BED5" TextWrapping="Wrap"/></StackPanel></Border><Border Background="#2A2138" CornerRadius="6" Padding="12"><StackPanel><TextBlock Text="ADVANCED" FontWeight="Bold"/><TextBlock Text="Includes cleanup, hibernation, telemetry and Xbox app removal." Foreground="#C8BED5" TextWrapping="Wrap"/></StackPanel></Border></StackPanel></Border></Grid></Grid></TabItem>
<TabItem Header="Config"><StackPanel Margin="18"><TextBlock Text="SYSTEM CONFIGURATION" Foreground="#B995F1" FontSize="17"/><TextBlock Text="Defender, Bluetooth, Windows Update, Microsoft Store, Gaming Services and essential drivers remain intact." TextWrapping="Wrap" Margin="0,10"/></StackPanel></TabItem>
<TabItem Header="Updates"><StackPanel Margin="18"><TextBlock Text="WINDOWS UPDATE" Foreground="#B995F1" FontSize="17"/><TextBlock Text="Windows Update remains enabled." Margin="0,10"/><Button x:Name="OpenUpdate" Content="OPEN WINDOWS UPDATE SETTINGS" HorizontalAlignment="Left"/></StackPanel></TabItem>
<TabItem Header="Gaming"><StackPanel Margin="18"><TextBlock Text="GAMING / FORTNITE" Foreground="#B995F1" FontSize="17"/><TextBlock Text="Windows-level preferences only. No CPU overclock, voltage changes, thermal-protection disabling or guaranteed FPS claims. Keep laptop cooling protections enabled." TextWrapping="Wrap" Margin="0,10"/></StackPanel></TabItem>
<TabItem Header="Log"><TextBox x:Name="LogBox" Margin="10" Background="#110D17" Foreground="#D9C9F0" FontFamily="Consolas" IsReadOnly="True" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"/></TabItem>
</TabControl></DockPanel></Window>
'@
$window=[Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($x));$script:LogBox=$window.FindName('LogBox')
$names=@('GameMode','GameDVR','BackgroundApps','Transparency','MouseAccel','PowerPlan','TempCleanup','Hibernation','Telemetry','XboxApps');$checks=@($names|ForEach-Object{$window.FindName($_)})
$window.FindName('Clear').Add_Click({foreach($c in $checks){$c.IsChecked=$false}})
$window.FindName('SelectAll').Add_Click({foreach($c in $checks){$c.IsChecked=$true}})
$window.FindName('Minimal').Add_Click({foreach($c in $checks){$c.IsChecked=($c.Tag -in @('GameMode','GameDVR'))}})
$window.FindName('Standard').Add_Click({foreach($c in $checks){$c.IsChecked=($c.Tag -in @('GameMode','GameDVR','Transparency','MouseAccel'))}})
$window.FindName('Advanced').Add_Click({foreach($c in $checks){$c.IsChecked=$true}})
$window.FindName('OpenUpdate').Add_Click({Start-Process 'ms-settings:windowsupdate'})
$window.FindName('Undo').Add_Click({if([System.Windows.MessageBox]::Show('Restore the recorded registry, service and power settings? App removal and cleanup are not restored.','Solar Restore','YesNo','Warning') -eq 'Yes'){Restore}})
$window.FindName('Run').Add_Click({
 $chosen=@($checks|Where-Object{$_.IsChecked}|ForEach-Object{[string]$_.Tag})
 if(!$chosen.Count){[System.Windows.MessageBox]::Show('Select at least one tweak.','Solar')|Out-Null;return}
 $opt=@($chosen|Where-Object{$_ -in @('Hibernation','Telemetry','XboxApps','TempCleanup')})
 $msg='Apply these actions?'+[Environment]::NewLine+[Environment]::NewLine+($chosen -join [Environment]::NewLine)
 if($opt.Count){$msg+=[Environment]::NewLine+[Environment]::NewLine+'Optional changes: '+($opt -join ', ')}
 if([System.Windows.MessageBox]::Show($msg,'Confirm Solar Tweaks','YesNo','Warning') -ne 'Yes'){return}
 $script:Backup=Join-Path $script:Root ('Backup-'+(Get-Date -Format 'yyyyMMdd-HHmmss'));New-Item $script:Backup -ItemType Directory -Force|Out-Null;$script:RegBackup=Join-Path $script:Backup 'registry.jsonl'
 foreach($id in $chosen){$window.FindName('Status').Text='Applying '+$id;try{Apply $id}catch{Log ('FAILED '+$id+': '+$_.Exception.Message)}}
 $window.FindName('Status').Text='Finished — review the Log tab.';Log 'Selected actions completed.'
})
Log 'Solar Tweaking Util started.';$null=$window.ShowDialog()
