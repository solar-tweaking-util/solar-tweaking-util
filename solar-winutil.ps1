# Solar Tweaking Util - official WinUtil UI with Solar branding
# Downloads the compiled WinUtil release asset (case-sensitive filename: Winutil.ps1).
# Upstream project and MIT license: https://github.com/ChrisTitusTech/winutil
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Write-Host 'Solar Tweaking Util' -ForegroundColor Magenta
Write-Host 'Downloading the official compiled WinUtil release...' -ForegroundColor Gray
try {
    $uri = 'https://github.com/ChrisTitusTech/winutil/releases/latest/download/Winutil.ps1'
    $response = Invoke-WebRequest -Uri $uri -UseBasicParsing
    $source = [string]$response.Content
    if ([string]::IsNullOrWhiteSpace($source)) { throw 'WinUtil download was empty.' }
    if ($source -match '(?i)<html|404: Not Found|Page not found') { throw 'GitHub returned a web page instead of the WinUtil PowerShell release file.' }
    $titlePattern = 'Title\s*=\s*(["''])WinUtil\1'
    if ($source -notmatch $titlePattern) { throw 'The downloaded WinUtil release does not contain its expected Window title. The script was not modified.' }
    $source = [regex]::Replace($source, $titlePattern, 'Title="Solar Tweaking Util"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase, [TimeSpan]::FromSeconds(3))
    $logoPattern = '(?m)^\s*\$NavLogoPanel\.Children\.Add\(\(Invoke-WinUtilAssets\s+-Type\s+["'']logo["'']\s+-Size\s+25\)\)\s*\|\s*Out-Null\s*$'
    if ($source -notmatch $logoPattern) { throw 'The downloaded WinUtil release does not contain its expected navigation-logo hook. No tweaks were applied.' }
    $logoReplacement = @'
        $solarLogo = New-Object System.Windows.Controls.Border
        $solarLogo.Width = 25
        $solarLogo.Height = 25
        $solarLogo.CornerRadius = [System.Windows.CornerRadius]::new(5)
        $solarLogo.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#B78AF2')
        $solarLetter = New-Object System.Windows.Controls.TextBlock
        $solarLetter.Text = 'S'
        $solarLetter.FontSize = 18
        $solarLetter.FontWeight = [System.Windows.FontWeights]::Bold
        $solarLetter.Foreground = [System.Windows.Media.Brushes]::White
        $solarLetter.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $solarLetter.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $solarLogo.Child = $solarLetter
        $NavLogoPanel.Children.Add($solarLogo) | Out-Null
'@
    $source = [regex]::Replace($source, $logoPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $logoReplacement.TrimEnd() }, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase, [TimeSpan]::FromSeconds(3))
    Write-Host 'Solar title and light-purple S logo applied. Starting WinUtil...' -ForegroundColor Green
    Invoke-Expression $source
} catch {
    Write-Host ('Solar Tweaking Util could not start: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Stopped before applying Windows tweaks.' -ForegroundColor Yellow
    throw
}