# Solar Tweaking Util - official WinUtil UI with Solar branding
# Resolves the current release asset through the GitHub API so filename casing cannot break downloads.
# Upstream project and MIT license: https://github.com/ChrisTitusTech/winutil
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Write-Host 'Solar Tweaking Util' -ForegroundColor Magenta
Write-Host 'Resolving the official Chris Titus Tech WinUtil release...' -ForegroundColor Gray

try {
    # Read the actual asset name and URL from the official release metadata.
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/ChrisTitusTech/winutil/releases/latest' -UseBasicParsing
    $asset = $release.assets | Where-Object { $_.name -ieq 'winutil.ps1' } | Select-Object -First 1
    if (-not $asset -or [string]::IsNullOrWhiteSpace($asset.browser_download_url)) {
        throw 'GitHub latest-release metadata did not include the WinUtil PowerShell asset.'
    }
    Write-Host ('Downloading WinUtil ' + $release.tag_name + ' (' + $asset.name + ')...') -ForegroundColor Gray
    $source = [string](Invoke-RestMethod -Uri $asset.browser_download_url -UseBasicParsing)
    if ([string]::IsNullOrWhiteSpace($source) -or $source.Length -lt 100000) {
        throw ('The release asset did not look like the full compiled script. Downloaded characters: ' + $source.Length)
    }
    if ($source -match '(?is)^\s*(?:<!doctype html|<html|\{\s*"message"\s*:)') {
        throw 'GitHub returned an error page instead of the WinUtil script.'
    }

    # The compiled release embeds xaml/inputXML.xaml as $inputXML.
    $titlePattern = 'Title\s*=\s*"WinUtil"'
    if ($source -notmatch $titlePattern) {
        throw 'The downloaded release did not contain the expected XAML Window title. No changes were applied.'
    }
    $source = [regex]::Replace($source, $titlePattern, 'Title="Solar Tweaking Util"', 1)

    # Patch the real logo-building statement in Start-WinUtilUserInterface.
    $logoPattern = '(?m)^\s*\$NavLogoPanel\.Children\.Add\(\(Invoke-WinUtilAssets -Type "logo" -Size 25\)\) \| Out-Null\s*$'
    if ($source -notmatch $logoPattern) {
        throw 'The downloaded release did not contain the expected WinUtil navigation-logo hook. No changes were applied.'
    }
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
    $source = [regex]::Replace($source, $logoPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $logoReplacement.TrimEnd() }, 1)

    Write-Host ('Solar branding applied to WinUtil ' + $release.tag_name + '. Starting the original WinUtil interface...') -ForegroundColor Green
    Invoke-Expression $source
} catch {
    Write-Host ('Solar Tweaking Util could not start: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'The launcher stopped before applying Windows tweaks.' -ForegroundColor Yellow
    throw
}