# Solar Tweaking Util - Chris Titus Tech WinUtil UI edition
# The actual WinUtil WPF interface, tabs, controls, and feature engine are loaded from upstream.
# Solar branding replaces only the window title and navigation logo.
# Upstream: https://github.com/ChrisTitusTech/winutil
# License: MIT. Copyright (c) 2022 CT Tech Group LLC. See upstream LICENSE.
# This script does not disable Windows security protections or alter WinUtil's feature engine.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

Write-Host 'Solar Tweaking Util' -ForegroundColor Magenta
Write-Host 'Loading Chris Titus Tech WinUtil interface with Solar branding...' -ForegroundColor Gray

try {
    $upstreamUrl = 'https://christitus.com/win'
    $response = Invoke-WebRequest -Uri $upstreamUrl -UseBasicParsing
    $source = [string]$response.Content
    if ([string]::IsNullOrWhiteSpace($source)) { throw 'The upstream WinUtil download was empty.' }

    # Patch the actual upstream XAML window title.
    $titleOld = 'Title="WinUtil"'
    if (-not $source.Contains($titleOld)) {
        throw 'The current upstream WinUtil XAML title marker was not found. No changes were applied.'
    }
    $source = $source.Replace($titleOld, 'Title="Solar Tweaking Util"')

    # Patch the real WinUtil navigation logo insertion point in Start-WinUtilUserInterface.
    $logoOld = '$NavLogoPanel.Children.Add((Invoke-WinUtilAssets -Type "logo" -Size 25)) | Out-Null'
    if (-not $source.Contains($logoOld)) {
        throw 'The current upstream WinUtil navigation logo hook was not found. No changes were applied.'
    }

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

    Write-Host 'Solar branding applied to the real WinUtil interface.' -ForegroundColor Green
    Invoke-Expression $source
}
catch {
    Write-Host ('Solar Tweaking Util could not start: ' + $_.Exception.Message) -ForegroundColor Red
    throw
}
