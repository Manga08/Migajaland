[CmdletBinding()]
param(
    [string]$ArchivePath,
    [switch]$SkipRunningCheck
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Stop-WithMessage([string]$Message) {
    Write-Host "`nERROR: $Message" -ForegroundColor Red
    exit 1
}

function Set-IniValue([System.Collections.Generic.List[string]]$Lines, [string]$Key, [string]$Value) {
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match ('^' + [regex]::Escape($Key) + '=')) {
            $Lines[$i] = "$Key=$Value"
            return
        }
    }
    $general = $Lines.IndexOf('[General]')
    if ($general -lt 0) { Stop-WithMessage 'instance.cfg no contiene la seccion [General].' }
    $Lines.Insert($general + 1, "$Key=$Value")
}

$running = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -match '^(java|javaw|freesmlauncher|prismlauncher)\.exe$' -and
    ($_.CommandLine -match '(?i)FreesmLauncher|Migajaland|minecraft')
})
if (-not $SkipRunningCheck -and $running.Count -gt 0) { Stop-WithMessage 'Cierra Minecraft y Freesm Launcher completamente antes de instalar.' }

if ([string]::IsNullOrWhiteSpace($ArchivePath)) {
    $archives = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'Migajaland-Copia-Personal-*.zip' -File | Sort-Object LastWriteTime -Descending)
    if ($archives.Count -eq 0) { Stop-WithMessage 'Coloca el ZIP personal junto a este instalador o arrastralo sobre el BAT.' }
    $ArchivePath = $archives[0].FullName
}
$ArchivePath = [System.IO.Path]::GetFullPath($ArchivePath)
if (-not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) { Stop-WithMessage "No existe el archivo: $ArchivePath" }

$hashPath = "$ArchivePath.sha256.txt"
if (Test-Path -LiteralPath $hashPath) {
    $expected = ((Get-Content -LiteralPath $hashPath -Raw).Trim() -split '\s+')[0]
    $actual = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash
    if ($actual -ne $expected) { Stop-WithMessage 'El SHA-256 no coincide. La copia puede estar incompleta o danada.' }
    Write-Host 'Integridad del ZIP verificada correctamente.' -ForegroundColor Green
} else {
    Write-Warning 'No se encontro el archivo SHA-256; se continuara sin verificar la transferencia.'
}

$instancesRoot = Join-Path $env:APPDATA 'FreesmLauncher\instances'
if (-not (Test-Path -LiteralPath (Split-Path $instancesRoot -Parent))) {
    Stop-WithMessage 'Abre Freesm Launcher una vez, cierralo y vuelve a ejecutar este instalador.'
}
New-Item -ItemType Directory -Path $instancesRoot -Force | Out-Null
$destination = Join-Path $instancesRoot 'Migajaland-Portatil'
if (Test-Path -LiteralPath $destination) {
    Stop-WithMessage "Ya existe $destination. No se sobrescribio nada. Renombra o elimina esa instancia manualmente si quieres repetir la instalacion."
}

$zip = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
try {
    if (-not ($zip.Entries | Where-Object FullName -eq 'migajaland-migracion.json')) {
        Stop-WithMessage 'El ZIP no fue creado por la herramienta de migracion de Migajaland.'
    }
    New-Item -ItemType Directory -Path $destination | Out-Null
    $destinationFull = [System.IO.Path]::GetFullPath($destination) + [System.IO.Path]::DirectorySeparatorChar
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -eq 'migajaland-migracion.json' -or [string]::IsNullOrEmpty($entry.Name)) { continue }
        $target = [System.IO.Path]::GetFullPath((Join-Path $destination $entry.FullName.Replace('/', '\')))
        if (-not $target.StartsWith($destinationFull, [StringComparison]::OrdinalIgnoreCase)) {
            Stop-WithMessage 'El ZIP contiene una ruta no valida.'
        }
        $parent = Split-Path $target -Parent
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $false)
    }
} catch {
    if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Recurse -Force }
    throw
} finally {
    $zip.Dispose()
}

$instanceCfg = Join-Path $destination 'instance.cfg'
$minecraft = Join-Path $destination 'minecraft'
if (-not (Test-Path -LiteralPath $instanceCfg) -or -not (Test-Path -LiteralPath $minecraft -PathType Container)) {
    Remove-Item -LiteralPath $destination -Recurse -Force
    Stop-WithMessage 'La copia no contiene una instancia valida de Freesm.'
}

$lines = [System.Collections.Generic.List[string]]::new()
Get-Content -LiteralPath $instanceCfg | ForEach-Object { $lines.Add($_) }
Set-IniValue $lines 'name' 'Migajaland-Portatil'
Set-IniValue $lines 'ManagedPackName' 'Migajaland-Portatil'
Set-IniValue $lines 'AutomaticJava' 'true'
Set-IniValue $lines 'OverrideJavaLocation' 'false'
Set-IniValue $lines 'JavaPath' ''
Set-IniValue $lines 'OverrideMemory' 'true'
Set-IniValue $lines 'MinMemAlloc' '512'
Set-IniValue $lines 'LowMemWarning' 'true'

try {
    $totalBytes = [int64](Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory
    $maxMiB = if ($totalBytes -ge 12GB) { 6144 } else { 4096 }
    $totalGiB = [math]::Round($totalBytes / 1GB, 1)
} catch {
    $maxMiB = 4096
    $totalGiB = 'desconocida'
}
Set-IniValue $lines 'MaxMemAlloc' ([string]$maxMiB)
[System.IO.File]::WriteAllLines($instanceCfg, $lines, [System.Text.UTF8Encoding]::new($false))

Write-Host "`nINSTALACION TERMINADA" -ForegroundColor Green
Write-Host "Instancia: $destination"
Write-Host "RAM detectada: $totalGiB GB; limite de Minecraft: $([math]::Round($maxMiB / 1024)) GB."
Write-Host "`nAbre Freesm, agrega o selecciona el usuario Manga y ejecuta Migajaland-Portatil." -ForegroundColor Cyan
Write-Host 'En el servidor usa tu misma contrasena con /login. No vuelvas a registrarte.' -ForegroundColor Yellow
