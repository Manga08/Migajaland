param(
    [string]$PackUrl,
    [string]$InstanceRoot,
    [switch]$NonInteractive,
    [switch]$AllowLauncherRunningForTest
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$utf8 = [System.Text.UTF8Encoding]::new($false)
$unsupUrl = "https://git.sleeping.town/exa/unsup/releases/download/v1.2.7/unsup-1.2.7.jar"
$unsupSha256 = "34483991b6bf218636d6769466faa5246901074bce731538147aa255cc046d59"

function Stop-WithMessage {
    param([Parameter(Mandatory)][string]$Message)
    throw $Message
}

function Select-InstanceFolder {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
    $dialog.Description = "Selecciona la carpeta de la instancia Migajaland de Freesm Launcher"
    $dialog.UseDescriptionForTitle = $true
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Stop-WithMessage "No se selecciono ninguna instancia."
    }
    $dialog.SelectedPath
}

function Resolve-MigajalandInstance {
    if ($InstanceRoot) { return [System.IO.Path]::GetFullPath($InstanceRoot) }

    $instancesRoot = Join-Path $env:APPDATA "FreesmLauncher\instances"
    $candidates = @()
    if (Test-Path -LiteralPath $instancesRoot -PathType Container) {
        $candidates = @(Get-ChildItem -LiteralPath $instancesRoot -Directory | Where-Object {
            $_.Name -match "Migajaland" -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "instance.cfg") -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "minecraft") -PathType Container)
        })
    }
    if ($candidates.Count -eq 1) { return $candidates[0].FullName }
    if ($NonInteractive) {
        Stop-WithMessage "No se pudo elegir una unica instancia Migajaland. Usa -InstanceRoot."
    }
    if ($candidates.Count -gt 1) {
        Write-Host "Se encontraron varias instancias Migajaland:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $candidates.Count; $i++) { Write-Host "[$($i + 1)] $($candidates[$i].FullName)" }
        $selection = Read-Host "Escribe el numero de la instancia que usan para jugar"
        $number = 0
        if ([int]::TryParse($selection, [ref]$number) -and $number -ge 1 -and $number -le $candidates.Count) {
            return $candidates[$number - 1].FullName
        }
        Stop-WithMessage "Seleccion no valida."
    }
    Select-InstanceFolder
}

function Set-IniValue {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][System.Collections.Generic.List[string]]$Lines,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Value
    )
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match ('^' + [regex]::Escape($Key) + '=')) {
            $Lines[$i] = "$Key=$Value"
            return
        }
    }
    $generalIndex = $Lines.IndexOf('[General]')
    if ($generalIndex -lt 0) { Stop-WithMessage "instance.cfg no contiene la seccion [General]." }
    $Lines.Insert($generalIndex + 1, "$Key=$Value")
}

function Set-JsonProperty {
    param(
        [Parameter(Mandatory)][psobject]$Object,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value
    )
    if ($Object.PSObject.Properties[$Name]) {
        $Object.$Name = $Value
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Get-PackwizFileHashes {
    param([Parameter(Mandatory)][string]$IndexText)
    $result = @{}
    $currentFile = $null
    $currentHash = $null
    foreach ($line in ($IndexText -split "`r?`n")) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '[[files]]') {
            if ($currentFile -and $currentHash) { $result[$currentFile] = $currentHash }
            $currentFile = $null
            $currentHash = $null
        } elseif ($trimmed -match '^file\s*=\s*"([^"]+)"\s*$') {
            $currentFile = $Matches[1]
        } elseif ($trimmed -match '^hash\s*=\s*"([0-9a-fA-F]+)"\s*$') {
            $currentHash = $Matches[1].ToLowerInvariant()
        }
    }
    if ($currentFile -and $currentHash) { $result[$currentFile] = $currentHash }
    $result
}

try {
    if (-not $PackUrl) {
        $urlFile = Join-Path $PSScriptRoot "URL-ACTUALIZACIONES.txt"
        if (Test-Path -LiteralPath $urlFile -PathType Leaf) { $PackUrl = (Get-Content -Raw -LiteralPath $urlFile).Trim() }
    }
    if (-not [uri]::IsWellFormedUriString($PackUrl, [uriKind]::Absolute) -or $PackUrl -notmatch '^https?://') {
        Stop-WithMessage "Falta una URL valida para pack.toml. Este paquete aun no esta publicado."
    }
    if (-not $PackUrl.EndsWith('/pack.toml', [System.StringComparison]::OrdinalIgnoreCase)) {
        Stop-WithMessage "La URL de actualizaciones debe terminar en /pack.toml"
    }

    Write-Host "Comprobando la fuente oficial de actualizaciones..."
    $packResponse = Invoke-WebRequest -UseBasicParsing -Uri $PackUrl -TimeoutSec 20
    $packContent = if ($packResponse.Content -is [byte[]]) {
        [System.Text.Encoding]::UTF8.GetString($packResponse.Content)
    } else {
        [string]$packResponse.Content
    }
    if ($packResponse.StatusCode -ne 200 -or $packContent -notmatch 'pack-format\s*=\s*"packwiz:') {
        Stop-WithMessage "La URL respondio, pero no contiene un pack.toml valido."
    }
    $indexBlock = [regex]::Match($packContent, '(?ms)^\[index\]\s*(?<body>.*?)(?=^\[|\z)')
    if (-not $indexBlock.Success) { Stop-WithMessage "pack.toml no contiene una seccion [index] valida." }
    $indexBody = $indexBlock.Groups['body'].Value
    if ($indexBody -notmatch '(?m)^file\s*=\s*"([^"]+)"\s*$') { Stop-WithMessage "pack.toml no indica el archivo de indice." }
    $indexFile = $Matches[1]
    if ($indexBody -notmatch '(?m)^hash-format\s*=\s*"sha256"\s*$') { Stop-WithMessage "El indice no usa SHA-256." }
    if ($indexBody -notmatch '(?m)^hash\s*=\s*"([0-9a-fA-F]{64})"\s*$') { Stop-WithMessage "pack.toml no contiene un hash SHA-256 valido para el indice." }
    $expectedIndexHash = $Matches[1].ToLowerInvariant()

    $instance = Resolve-MigajalandInstance
    $instanceCfg = Join-Path $instance "instance.cfg"
    $minecraft = Join-Path $instance "minecraft"
    if (-not (Test-Path -LiteralPath $instanceCfg -PathType Leaf) -or -not (Test-Path -LiteralPath $minecraft -PathType Container)) {
        Stop-WithMessage "La carpeta no parece una instancia valida de Freesm: $instance"
    }

    $launcherRunning = @(Get-Process -Name "freesmlauncher" -ErrorAction SilentlyContinue).Count -gt 0
    if ($launcherRunning -and -not $AllowLauncherRunningForTest) { Stop-WithMessage "Cierra Freesm Launcher por completo y vuelve a ejecutar este archivo." }
    try {
        $escaped = [regex]::Escape($instance)
        $gameRunning = @(Get-CimInstance Win32_Process -Filter "Name = 'javaw.exe' OR Name = 'java.exe'" -ErrorAction Stop | Where-Object { $_.CommandLine -match $escaped }).Count -gt 0
        if ($gameRunning) { Stop-WithMessage "Minecraft sigue abierto en esta instancia. Cierralo antes de continuar." }
    } catch [Microsoft.Management.Infrastructure.CimException] {
        Write-Warning "No se pudo comprobar si Java sigue abierto; continuando con precaucion."
    }

    $temporaryId = [guid]::NewGuid().ToString('N')
    $download = Join-Path ([System.IO.Path]::GetTempPath()) ("migajaland-unsup-" + $temporaryId + ".jar")
    $indexDownload = Join-Path ([System.IO.Path]::GetTempPath()) ("migajaland-index-" + $temporaryId + ".toml")
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $unsupUrl -OutFile $download -TimeoutSec 60
        $downloadHash = (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($downloadHash -ne $unsupSha256) { Stop-WithMessage "La firma SHA-256 de unsup no coincide; no se modifico la instancia." }

        $indexUrl = [uri]::new([uri]$PackUrl, $indexFile).AbsoluteUri
        Invoke-WebRequest -UseBasicParsing -Uri $indexUrl -OutFile $indexDownload -TimeoutSec 30
        $actualIndexHash = (Get-FileHash -LiteralPath $indexDownload -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualIndexHash -ne $expectedIndexHash) { Stop-WithMessage "El indice remoto no coincide con el hash firmado por pack.toml." }
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backup = Join-Path $instance (".migajaland-backups\actualizador-" + $timestamp)
        New-Item -ItemType Directory -Path $backup -Force | Out-Null
        Copy-Item -LiteralPath $instanceCfg -Destination $backup -Force
        foreach ($name in @('unsup.jar', 'unsup.ini', '.unsup-state.json', '.migajaland-updater.json', 'options.txt', 'options.txt.orig', 'servers.dat')) {
            $source = Join-Path $minecraft $name
            if (Test-Path -LiteralPath $source -PathType Leaf) { Copy-Item -LiteralPath $source -Destination $backup -Force }
        }

        $originalOptions = Join-Path $minecraft 'options.txt.orig'
        if (Test-Path -LiteralPath $originalOptions -PathType Leaf) {
            if ($NonInteractive) {
                Write-Warning "Existe options.txt.orig. Puedes recuperarlo manualmente desde $originalOptions"
            } else {
                Write-Host "`nSe encontro una copia de tus opciones anteriores: options.txt.orig" -ForegroundColor Yellow
                $restoreOptions = Read-Host "Quieres recuperar ahora esos graficos y controles? Escribe S para restaurarlos"
                if ($restoreOptions -match '^(?i:s|si|sí|y|yes)$') {
                    Copy-Item -LiteralPath $originalOptions -Destination (Join-Path $minecraft 'options.txt') -Force
                    Write-Host "Opciones anteriores recuperadas." -ForegroundColor Green
                }
            }
        }

        $cfgLines = [System.Collections.Generic.List[string]]::new()
        Get-Content -LiteralPath $instanceCfg | ForEach-Object { $cfgLines.Add($_) }
        $jvmLine = @($cfgLines | Where-Object { $_ -match '^JvmArgs=' } | Select-Object -First 1)
        $existingArgs = if ($jvmLine.Count) { $jvmLine[0].Substring('JvmArgs='.Length).Trim() } else { '' }
        $agentArg = '-javaagent:unsup.jar'
        if ($existingArgs -notmatch '(?i)(^|\s)-javaagent:("?)(?:\.\\|\./)?unsup\.jar\2(?=\s|$)') {
            $existingArgs = ($agentArg + ' ' + $existingArgs).Trim()
        }
        Set-IniValue -Lines $cfgLines -Key 'OverrideJavaArgs' -Value 'true'
        Set-IniValue -Lines $cfgLines -Key 'JvmArgs' -Value $existingArgs

        # Freesm guarda la memoria por instancia en instance.cfg. Migajaland
        # nunca asigna mas de 6 GiB para dejar RAM disponible a Windows,
        # Discord, el launcher y la grafica integrada.
        try {
            $totalBytes = [int64](Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory
            $totalGiB = [math]::Round($totalBytes / 1GB, 1)
            $maxMiB = if ($totalBytes -ge 12GB) { 6144 } else { 4096 }
            Set-IniValue -Lines $cfgLines -Key 'OverrideMemory' -Value 'true'
            Set-IniValue -Lines $cfgLines -Key 'MinMemAlloc' -Value '512'
            Set-IniValue -Lines $cfgLines -Key 'MaxMemAlloc' -Value ([string]$maxMiB)
            Set-IniValue -Lines $cfgLines -Key 'LowMemWarning' -Value 'true'
            Write-Host "RAM detectada: aproximadamente $totalGiB GB; Migajaland usara como maximo $([math]::Round($maxMiB / 1024)) GB." -ForegroundColor Cyan
        } catch {
            $maxMiB = 4096
            Set-IniValue -Lines $cfgLines -Key 'OverrideMemory' -Value 'true'
            Set-IniValue -Lines $cfgLines -Key 'MinMemAlloc' -Value '512'
            Set-IniValue -Lines $cfgLines -Key 'MaxMemAlloc' -Value '4096'
            Set-IniValue -Lines $cfgLines -Key 'LowMemWarning' -Value 'true'
            Write-Warning "No se pudo consultar la RAM fisica; se aplico el limite seguro de 4 GB."
        }

        Copy-Item -LiteralPath $download -Destination (Join-Path $minecraft 'unsup.jar') -Force
        $unsupIni = @"
version=1
preset=minecraft
source_format=packwiz
source=$PackUrl
force_env=client
behavior=semi
enforce_secure_hashes=true
update_mmc_pack=false
subtitle=Comprobando Migajaland...

[branding]
modpack_name=Migajaland
"@
        [System.IO.File]::WriteAllText((Join-Path $minecraft 'unsup.ini'), $unsupIni, $utf8)
        [System.IO.File]::WriteAllLines($instanceCfg, $cfgLines, $utf8)

        # options.txt y servers.dat pertenecen al jugador y no forman parte del
        # canal automatico. Tambien se quitan de estados creados por versiones
        # antiguas del instalador para impedir que unsup intente borrarlos.
        $statePath = Join-Path $minecraft '.unsup-state.json'
        if (Test-Path -LiteralPath $statePath -PathType Leaf) {
            try {
                $state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
            } catch {
                Stop-WithMessage "El estado existente de unsup no es JSON valido. Se guardo una copia en $backup"
            }
        } else {
            $state = [pscustomobject]@{}
        }
        if (-not $state.PSObject.Properties['packwiz']) {
            Set-JsonProperty -Object $state -Name 'packwiz' -Value ([pscustomobject]@{})
        }
        if (-not $state.packwiz.PSObject.Properties['lastState']) {
            Set-JsonProperty -Object $state.packwiz -Name 'lastState' -Value ([pscustomobject]@{})
        }
        foreach ($personalFile in @('options.txt', 'servers.dat')) {
            $state.packwiz.lastState.PSObject.Properties.Remove($personalFile)
        }
        [System.IO.File]::WriteAllText($statePath, ($state | ConvertTo-Json -Depth 100 -Compress) + "`n", $utf8)

        $marker = [ordered]@{
            pack = 'Migajaland'
            updater = 'unsup'
            updater_version = '1.2.7'
            source = $PackUrl
            maximum_memory_mib = $maxMiB
            installed_at = (Get-Date).ToString('o')
            backup = $backup
        }
        [System.IO.File]::WriteAllText(
            (Join-Path $minecraft '.migajaland-updater.json'),
            ($marker | ConvertTo-Json -Depth 4) + "`n",
            $utf8
        )
    } finally {
        if (Test-Path -LiteralPath $download) { Remove-Item -LiteralPath $download -Force }
        if (Test-Path -LiteralPath $indexDownload) { Remove-Item -LiteralPath $indexDownload -Force }
    }

    Write-Host "`nActualizaciones automaticas activadas." -ForegroundColor Green
    Write-Host "Instancia: $instance"
    Write-Host "Copia de seguridad: $backup"
    Write-Host "RAM maxima configurada: $([math]::Round($maxMiB / 1024)) GB"
    Write-Host "Desde ahora basta con abrir Migajaland y pulsar Jugar."
    exit 0
} catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
