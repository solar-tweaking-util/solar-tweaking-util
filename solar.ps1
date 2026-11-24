# Solar Tweaking Util — WinUtil interface edition
# Uses the official Chris Titus Tech WinUtil UI and feature engine, with Solar branding.
# Upstream project: https://github.com/ChrisTitusTech/winutil (MIT License).
# This launcher downloads the current upstream script at run time and changes only the window title and navigation logo.
# Run from an elevated PowerShell session. WinUtil itself handles its normal elevation and system operations.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$upstreamUrl = 'https://christitus.com/win'

Write-Host 'Solar Tweaking Util' -ForegroundColor Magenta
Write-Host 'Loading the official WinUtil interface...' -ForegroundColor Gray

try {
    $response = Invoke-WebRequest -Uri $upstreamUrl -UseBasicParsing
    $source = [string]$response.Content
    if ([string]::IsNullOrWhiteSpace($source)) { throw 'The WinUtil download was empty.' }

    # Rebrand the actual WinUtil WPF window.
    $source = $source.Replace('Title="WinUtil"', 'Title="Solar Tweaking Util"')

    # Replace WinUtil's own navigation logo with a Solar S tile in light purple.
    $logoPattern = '\$NavLogoPanel\.Children\.Add\(\(Invoke-WinUtilAssets -Type "logo" -Size 25\)\) \| Out-Null'
    $logoReplacement = @'
        $solarLogo = New-Object System.Windows.Controls.Border
        $solarLogo.Width = 28
        $solarLogo.Height = 28
        $solarLogo.CornerRadius = [System.Windows.CornerRadius]::new(6)
        $solarLogo.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#B78AF2')
        $solarLogo.Margin = [System.Windows.Thickness]::new(0,0,0,0)
        $solarLetter = New-Object System.Windows.Controls.TextBlock
        $solarLetter.Text = 'S'
        $solarLetter.FontSize = 21
        $solarLetter.FontWeight = [System.Windows.FontWeights]::Bold
        $solarLetter.Foreground = [System.Windows.Media.Brushes]::White
        $solarLetter.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $solarLetter.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $solarLogo.Child = $solarLetter
        $NavLogoPanel.Children.Add($solarLogo) | Out-Null
'@
    if ($source -notmatch $logoPattern) {
        throw 'Could not find the upstream WinUtil logo insertion point. No unbranded UI was launched.'
    }
    $source = [regex]::Replace($source, $logoPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $logoReplacement }, 1)

    Write-Host 'Solar branding applied. Starting WinUtil...' -ForegroundColor Green
    Invoke-Expression $source
} catch {
    Write-Host ('Solar Tweaking Util could not start: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'No Windows tweaks were applied by the launcher.' -ForegroundColor Yellow
    throw
}