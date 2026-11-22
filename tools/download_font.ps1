$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch { }

$Root = Split-Path -Parent $PSScriptRoot
$FontDir = Join-Path $Root 'game\assets\fonts'
New-Item -ItemType Directory -Force -Path $FontDir | Out-Null
$Target = Join-Path $FontDir 'NotoSansCJKsc-Regular.otf'

if ((Test-Path -LiteralPath $Target) -and ((Get-Item -LiteralPath $Target).Length -gt 5MB)) {
    Write-Host "[font] Already present: $Target"
    exit 0
}

$urls = @(
    'https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@main/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf',
    'https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf',
    'https://github.com/notofonts/noto-cjk/raw/main/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf'
)

$temp = Join-Path $FontDir 'NotoSansCJKsc-Regular.otf.part'
foreach ($url in $urls) {
    try {
        Write-Host "[font] Downloading $url"
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
        Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing -TimeoutSec 300
        $size = (Get-Item -LiteralPath $temp).Length
        if ($size -lt 5MB) {
            throw "File too small ($size bytes), probably an error page."
        }
        Move-Item -LiteralPath $temp -Destination $Target -Force
        Write-Host ("[font] OK: {0} ({1:N1} MB)" -f $Target, ($size / 1MB))
        exit 0
    }
    catch {
        Write-Warning "[font] Failed: $($_.Exception.Message)"
    }
}

if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
Write-Host ''
Write-Host '[font] Automatic download failed (network or mirror limit).' -ForegroundColor Yellow
Write-Host '  Manual option: download any Simplified-Chinese .otf/.ttf and put it in:'
Write-Host "  $FontDir"
Write-Host '  Suggested: Noto Sans CJK SC / Source Han Sans SC / LXGW WenKai.'
Write-Host '  The game loads the first font file it finds in that folder.'
Write-Host ''
exit 1