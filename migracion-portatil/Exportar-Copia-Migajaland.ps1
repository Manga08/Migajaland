[CmdletBinding()]
param([switch]$SkipRunningCheck)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Stop-WithMessage([string]$Message) {
    Write-Host "`nERROR: $Message" -ForegroundColor Red
    exit 1
}

function Assert-GameClosed {
    $running = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match '^(java|javaw|freesmlauncher|prismlauncher)\.exe$' -and
        ($_.CommandLine -match '(?i)FreesmLauncher|Migajaland|minecraft')
    })
    if ($running.Count -gt 0) {
        Stop-WithMessage 'Cierra Minecraft y Freesm Launcher completamente antes de exportar.'
    }
}

function Select-MigajalandInstance([string]$InstancesRoot) {
    $candidates = @(Get-ChildItem -LiteralPath $InstancesRoot -Directory -ErrorAction SilentlyContinue | Where-Object {
        (Test-Path -LiteralPath (Join-Path $_.FullName 'instance.cfg')) -and
        (Test-Path -LiteralPath (Join-Path $_.FullName 'minecraft\.migajaland-updater.json'))
    })
    if ($candidates.Count -eq 0) {
        Stop-WithMessage "No se encontro una instancia de Migajaland con el actualizador en $InstancesRoot"
    }
    if ($candidates.Count -eq 1) { return $candidates[0] }

    Write-Host 'Se encontraron varias instancias de Migajaland:' -ForegroundColor Cyan
    for ($i = 0; $i -lt $candidates.Count; $i++) {
        Write-Host "  [$($i + 1)] $($candidates[$i].Name)"
    }
    $choice = Read-Host 'Escribe el numero de la instancia que utilizas'
    $number = 0
    if (-not [int]::TryParse($choice, [ref]$number) -or $number -lt 1 -or $number -gt $candidates.Count) {
        Stop-WithMessage 'Seleccion no valida.'
    }
    return $candidates[$number - 1]
}

if (-not $SkipRunningCheck) { Assert-GameClosed }
$instancesRoot = Join-Path $env:APPDATA 'FreesmLauncher\instances'
if (-not (Test-Path -LiteralPath $instancesRoot -PathType Container)) {
    Stop-WithMessage 'Freesm Launcher no parece estar instalado para este usuario.'
}

$instance = Select-MigajalandInstance $instancesRoot
$stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$archive = Join-Path $PSScriptRoot "Migajaland-Copia-Personal-$stamp.zip"
$hashFile = "$archive.sha256.txt"
$excludedPrefixes = @(
    '.migajaland-backups/',
    'minecraft/.unsup-tmp/',
    'minecraft/logs/',
    'minecraft/crash-reports/',
    'minecraft/downloads/',
    'minecraft/debug/'
)
$excludedNames = @('minecraft/hs_err_pid', 'minecraft/replay_pid')

Write-Host "Instancia encontrada: $($instance.FullName)" -ForegroundColor Green
Write-Host 'Creando la copia. JourneyMap puede hacer que tarde varios minutos...' -ForegroundColor Cyan

$stream = [System.IO.File]::Open($archive, [System.IO.FileMode]::CreateNew)
try {
    $zip = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
    try {
        $manifest = [ordered]@{
            format = 1
            product = 'Migajaland'
            exported_at = (Get-Date).ToString('o')
            source_instance = $instance.Name
            destination_instance = 'Migajaland-Portatil'
        } | ConvertTo-Json
        $entry = $zip.CreateEntry('migajaland-migracion.json', [System.IO.Compression.CompressionLevel]::Optimal)
        $writer = [System.IO.StreamWriter]::new($entry.Open(), [System.Text.UTF8Encoding]::new($false))
        $writer.Write($manifest)
        $writer.Dispose()

        $files = @(Get-ChildItem -LiteralPath $instance.FullName -Recurse -File -Force)
        $written = 0
        foreach ($file in $files) {
            $relative = $file.FullName.Substring($instance.FullName.Length).TrimStart('\').Replace('\', '/')
            $skip = $false
            foreach ($prefix in $excludedPrefixes) {
                if ($relative.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { $skip = $true; break }
            }
            if (-not $skip) {
                foreach ($namePrefix in $excludedNames) {
                    if ($relative.StartsWith($namePrefix, [StringComparison]::OrdinalIgnoreCase)) { $skip = $true; break }
                }
            }
            if ($skip) { continue }

            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip, $file.FullName, $relative, [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
            $written++
            if (($written % 1000) -eq 0) { Write-Host "  Archivos copiados: $written" }
        }
    } finally {
        $zip.Dispose()
    }
} catch {
    $stream.Dispose()
    if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
    throw
} finally {
    $stream.Dispose()
}

$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
[System.IO.File]::WriteAllText($hashFile, "$hash  $([System.IO.Path]::GetFileName($archive))`r`n", [System.Text.UTF8Encoding]::new($false))
$sizeGiB = [math]::Round((Get-Item -LiteralPath $archive).Length / 1GB, 2)

Write-Host "`nCOPIA TERMINADA" -ForegroundColor Green
Write-Host "Archivo: $archive"
Write-Host "Tamano: $sizeGiB GB"
Write-Host "Verificacion: $hashFile"
Write-Host "`nPasa ambos archivos al portatil de forma privada. No publiques el ZIP." -ForegroundColor Yellow
