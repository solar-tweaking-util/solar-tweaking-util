# Solar Tweaking Util - Chris Titus Tech WinUtil UI with Solar branding
# Downloads the compiled stable WinUtil release, then changes only its window title and nav logo.
# Upstream: https://github.com/ChrisTitusTech/winutil (MIT License).
# No Windows tweaks are applied by this branding launcher itself.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host 'Solar Tweaking Util' -ForegroundColor Magenta
Write-Host 'Loading the compiled Chris Titus Tech WinUtil release...' -ForegroundColor Gray

try {
    # IMPORTANT: use the compiled release artifact. christitus.com/win is only a bootstrap launcher.
    $upstreamUrl = 'https://github.com/ChrisTitusTech/winutil/releases/latest/download/winutil.ps1'
    $response = Invoke-WebRequest -Uri $upstreamUrl -UseBasicParsing
    $source = [string]$response.Content
    if ([string]::IsNullOrWhiteSpace($source)) { throw 'The official WinUtil release download was empty.' }

    # Confirm this is the compiled WPF script before changing anything.
    $titleOld = 'Title="WinUtil"'
    $logoOld = '$NavLogoPanel.Children.Add((Invoke-WinUtilAssets -Type "logo" -Size 25)) | Out-Null'
    if (-not $source.Contains($titleOld)) { throw 'The downloaded release did not contain the expected WinUtil XAML title. No changes were applied.' }
    if (-not $source.Contains($logoOld)) { throw 'The downloaded release did not contain the expected WinUtil navigation logo hook. No changes were applied.' }

    $source = $source.Replace($titleOld, 'Title="Solar Tweaking Util"')
    $logoNew = @'
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
    $source = $source.Replace($logoOld, $logoNew.TrimEnd())

    Write-Host 'Solar title and light-purple S logo applied. Starting WinUtil...' -ForegroundColor Green
    Invoke-Expression $source
} catch {
    Write-Host ('Solar Tweaking Util could not start: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'The launcher stopped before applying any Windows tweaks.' -ForegroundColor Yellow
    throw
}