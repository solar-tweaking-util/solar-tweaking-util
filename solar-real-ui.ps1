# Solar Tweaking Util - Chris Titus Tech WinUtil UI with Solar branding
# Downloads and verifies the official compiled WinUtil release, then patches its embedded XAML title
# and the actual navigation-logo hook. Upstream project: https://github.com/ChrisTitusTech/winutil

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host 'Solar Tweaking Util' -ForegroundColor Magenta
Write-Host 'Downloading and verifying the official Chris Titus Tech WinUtil release...' -ForegroundColor Gray

$tempFile = Join-Path $env:TEMP ('solar-winutil-' + [Guid]::NewGuid().ToString('N') + '.ps1')

try {
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/ChrisTitusTech/winutil/releases/latest' -UseBasicParsing
    $asset = $release.assets | Where-Object { $_.name -ieq 'winutil.ps1' } | Select-Object -First 1

    if (-not $asset -or [string]::IsNullOrWhiteSpace($asset.browser_download_url)) {
        throw 'The official GitHub release did not provide the winutil.ps1 asset.'
    }

    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempFile -UseBasicParsing

    $file = Get-Item -LiteralPath $tempFile
    if ($asset.size -and $file.Length -ne [long]$asset.size) {
        throw ('WinUtil download size mismatch. Expected ' + $asset.size + ' bytes; received ' + $file.Length + '.')
    }

    if ($asset.digest -match '^sha256:([0-9a-fA-F]{64})$') {
        $expectedHash = $Matches[1].ToUpperInvariant()
        $actualHash = (Get-FileHash -LiteralPath $tempFile -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($actualHash -ne $expectedHash) {
            throw 'WinUtil SHA-256 verification failed. The downloaded file will not be run.'
        }
    }

    $source = [IO.File]::ReadAllText($tempFile)
    if ([string]::IsNullOrWhiteSpace($source) -or $source.Length -lt 100000) {
        throw 'The downloaded file is not a complete WinUtil PowerShell script.'
    }

    # Find the exact upstream statement by literal text. IndexOf avoids regex/CRLF anchoring failures.
    $logoStatement = '$NavLogoPanel.Children.Add((Invoke-WinUtilAssets -Type "logo" -Size 25)) | Out-Null'
    $logoIndex = $source.IndexOf($logoStatement, [StringComparison]::Ordinal)
    Write-Host ('DEBUG release: ' + $release.tag_name)
    Write-Host ('DEBUG file bytes: ' + (Get-Item -LiteralPath $tempFile).Length)
    Write-Host ('DEBUG source chars: ' + $source.Length)
    Write-Host ('DEBUG SHA256: ' + (Get-FileHash -LiteralPath $tempFile -Algorithm SHA256).Hash)
    Write-Host ('DEBUG logo index: ' + $logoIndex)
    if ($logoIndex -lt 0) {
        $candidate = $source -split "`n" | Where-Object { $_ -match 'NavLogoPanel.*Children.*Add' } | Select-Object -First 1
        Write-Host ('DEBUG candidate line: ' + $candidate)
        throw 'Logo hook not found in the downloaded release; diagnostic values printed above. No UI changes were made.'
    }
    if ($source.IndexOf($logoStatement, $logoIndex + $logoStatement.Length, [StringComparison]::Ordinal) -ge 0) {
        throw 'Found multiple WinUtil navigation-logo statements; refusing an ambiguous patch.'
    }

    # The compiled release embeds its WPF XAML in the $inputXML variable.
    $xamlStart = $source.IndexOf('$inputXML', [StringComparison]::OrdinalIgnoreCase)
    if ($xamlStart -lt 0) {
        throw 'Could not locate the embedded WinUtil XAML. No UI changes were made.'
    }

    $xamlTail = $source.Substring($xamlStart)
    $titleMatch = [regex]::Match($xamlTail, 'Title\s*=\s*"Winutil"', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $titleMatch.Success) {
        throw 'Could not locate the actual WinUtil window title in the embedded XAML. No UI changes were made.'
    }

    $absoluteTitleIndex = $xamlStart + $titleMatch.Index
    $newTitle = [regex]::Replace($titleMatch.Value, '"Winutil"', '"Solar Tweaking Util"', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $source = $source.Substring(0, $absoluteTitleIndex) + $newTitle + $source.Substring($absoluteTitleIndex + $titleMatch.Length)

    # Recalculate after changing the title because that edit shifts all later character offsets.
    $logoIndex = $source.IndexOf($logoStatement, [StringComparison]::Ordinal)
    if ($logoIndex -lt 0) {
        throw 'The WinUtil logo hook disappeared after the title edit. No UI changes were applied.'
    }

    $lineStart = $source.LastIndexOf("`n", $logoIndex)
    if ($lineStart -lt 0) { $lineStart = 0 } else { $lineStart++ }
    $indent = $source.Substring($lineStart, $logoIndex - $lineStart)
    if ($indent.Trim().Length -ne 0) {
        throw 'The WinUtil navigation-logo statement was not at the start of a line. No UI changes were made.'
    }

    $logoLines = @(
        '$solarLogo = New-Object System.Windows.Controls.Border',
        '$solarLogo.Width = 25',
        '$solarLogo.Height = 25',
        '$solarLogo.CornerRadius = [System.Windows.CornerRadius]::new(5)',
        '$solarBrushConverter = New-Object System.Windows.Media.BrushConverter',
        '$solarLogo.Background = $solarBrushConverter.ConvertFromString(''#B78AF2'')',
        '$solarLetter = New-Object System.Windows.Controls.TextBlock',
        '$solarLetter.Text = ''S''',
        '$solarLetter.FontSize = 18',
        '$solarLetter.FontWeight = [System.Windows.FontWeights]::Bold',
        '$solarLetter.Foreground = [System.Windows.Media.Brushes]::White',
        '$solarLetter.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center',
        '$solarLetter.VerticalAlignment = [System.Windows.VerticalAlignment]::Center',
        '$solarLogo.Child = $solarLetter',
        '$NavLogoPanel.Children.Add($solarLogo) | Out-Null'
    )

    $logoReplacement = ($logoLines | ForEach-Object { $indent + $_ }) -join [Environment]::NewLine
    $source = $source.Substring(0, $logoIndex) + $logoReplacement + $source.Substring($logoIndex + $logoStatement.Length)

    Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    $tempFile = $null

    Write-Host ('Solar branding applied to verified WinUtil ' + $release.tag_name + '.') -ForegroundColor Green
    Write-Host 'Starting the original WinUtil interface...' -ForegroundColor Gray

    # The upstream WinUtil launcher itself uses the IEX execution model.
    Invoke-Expression $source
}
catch {
    Write-Host ('Solar Tweaking Util could not start: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'No Windows tweaks were applied by this launcher.' -ForegroundColor Yellow
    throw
}
finally {
    if ($tempFile -and (Test-Path -LiteralPath $tempFile)) {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    }
}
