param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('run', 'editor', 'smoke', 'ui-smoke', 'export')]
    [string]$Task
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot

function Find-GodotMain {
    if ($env:GODOT_BIN -and (Test-Path -LiteralPath $env:GODOT_BIN)) {
        return (Resolve-Path -LiteralPath $env:GODOT_BIN).Path
    }

    $local = Join-Path $Root 'tools\Godot\Godot_v4.7.1-stable_win64.exe'
    if (Test-Path -LiteralPath $local) { return (Resolve-Path -LiteralPath $local).Path }

    $roots = @(
        'D:\14app',
        'D:\11AI'
    )
    if (Test-Path -LiteralPath 'D:\') {
        Get-ChildItem -LiteralPath 'D:\' -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like '03*' } |
            ForEach-Object { $roots += $_.FullName }
    }
    $roots += @(
        'C:\Program Files',
        (Join-Path $env:USERPROFILE 'Desktop'),
        (Join-Path $env:USERPROFILE 'Downloads')
    )

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $hit = Get-ChildItem -LiteralPath $root -Recurse -Depth 4 -File `
            -Filter 'Godot_v4*-stable_win64.exe' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notlike '*console*' } |
            Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }

    return $null
}

$godot = Find-GodotMain
if (-not $godot) {
    Write-Host ''
    Write-Host '[qlnu] Godot 4 executable not found.' -ForegroundColor Yellow
    Write-Host '  1) Put Godot_v4.x-stable_win64.exe into tools\Godot\, or'
    Write-Host '  2) Set env var GODOT_BIN to the Godot executable.'
    Write-Host '  Example (PowerShell): setx GODOT_BIN "D:\Godot\Godot_v4.7.1-stable_win64.exe"'
    Write-Host ''
    exit 1
}

$console = $godot -replace '\.exe$', '_console.exe'
if (-not (Test-Path -LiteralPath $console)) { $console = $godot }

Write-Host "[qlnu] Godot  : $godot"
Write-Host "[qlnu] Project: $Root"

switch ($Task) {
    'run' {
        & $godot --path $Root
        exit $LASTEXITCODE
    }
    'editor' {
        & $godot -e --path $Root
        exit $LASTEXITCODE
    }
    'smoke' {
        Write-Host '[qlnu] Running headless smoke test...'
        & $console --headless --path $Root -- --smoke
        $code = $LASTEXITCODE
        Write-Host "[qlnu] smoke exit code: $code"
        exit $code
    }
    'ui-smoke' {
        Write-Host '[qlnu] Running headless UI boot check...'
        & $console --headless --path $Root -- --ui-smoke
        $code = $LASTEXITCODE
        Write-Host "[qlnu] ui smoke exit code: $code"
        exit $code
    }
    'export' {
        $templates = Join-Path $env:APPDATA 'Godot\export_templates'
        $hasTemplate = $false
        if (Test-Path -LiteralPath $templates) {
            $hasTemplate = [bool](Get-ChildItem -LiteralPath $templates -Recurse -File `
                -Filter 'web*nothreads*release.zip' -ErrorAction SilentlyContinue |
                Select-Object -First 1)
            if (-not $hasTemplate) {
                $hasTemplate = [bool](Get-ChildItem -LiteralPath $templates -Recurse -File `
                    -Filter 'web*release.zip' -ErrorAction SilentlyContinue |
                    Select-Object -First 1)
            }
        }
        if (-not $hasTemplate) {
            Write-Host ''
            Write-Host '[qlnu] Web export templates not found.' -ForegroundColor Yellow
            Write-Host '  Editor menu: Editor > Manage Export Templates > Download and Install'
            Write-Host '  Or download Godot_v4.7.1-stable_export_templates.tpz and extract to:'
            Write-Host '  %APPDATA%\Godot\export_templates\4.7.1.stable\'
            Write-Host ''
            exit 2
        }

        $outDir = Join-Path $Root 'game\build\web'
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
        Write-Host "[qlnu] Exporting Web build to: $outDir"
        & $console --headless --path $Root --export-release 'Web' (Join-Path $outDir 'index.html')
        $code = $LASTEXITCODE
        if ($code -eq 0) {
            Write-Host '[qlnu] Export finished. Run serve_web.bat to preview.'
        }
        exit $code
    }
}