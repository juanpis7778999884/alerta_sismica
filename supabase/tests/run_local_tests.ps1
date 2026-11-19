param(
  [string]$BinDir,
  [int]$Port = 55432
)

$ErrorActionPreference = 'Stop'

if (-not $BinDir) {
  $svc = Get-CimInstance Win32_Service -Filter "Name='postgresql-x64-17'" -ErrorAction SilentlyContinue
  if ($svc -and $svc.PathName -match '"([^"]+)\\bin\\pg_ctl\.exe"') {
    $BinDir = $matches[1] + '\bin'
  } elseif ($svc -and $svc.PathName -match '([^\s]+)\\bin\\pg_ctl\.exe') {
    $BinDir = $matches[1] + '\bin'
  }
}

if (-not $BinDir) {
  throw 'No se pudo localizar PostgreSQL 17. Pase -BinDir explícitamente.'
}

$initdb = Join-Path $BinDir 'initdb.exe'
$pgctl = Join-Path $BinDir 'pg_ctl.exe'
$psql = Join-Path $BinDir 'psql.exe'
$createdb = Join-Path $BinDir 'createdb.exe'

foreach ($exe in @($initdb, $pgctl, $psql, $createdb)) {
  if (-not (Test-Path -LiteralPath $exe)) {
    throw "Falta el ejecutable $exe"
  }
}

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$migrationsDir = Join-Path $projectRoot 'supabase\migrations'
$testsDir = $PSScriptRoot
$tempParent = 'C:\Users\Usuario\AppData\Local\Temp\opencode'

if (-not (Test-Path -LiteralPath $tempParent)) {
  throw "No existe el directorio temporal autorizado $tempParent"
}

$tempRoot = Join-Path $tempParent 'alerta_sismica_pg_tests'
if (-not (Test-Path -LiteralPath $tempRoot)) {
  New-Item -ItemType Directory -Path $tempRoot | Out-Null
}

$runDir = Join-Path $tempRoot ('run_' + [guid]::NewGuid().ToString('N'))
$clusterDir = Join-Path $runDir 'cluster'
$logFile = Join-Path $runDir 'postgres.log'
New-Item -ItemType Directory -Path $clusterDir | Out-Null

function Invoke-Native {
  param([string]$Exe, [string[]]$Params)
  & $Exe @Params
  if ($LASTEXITCODE -ne 0) {
    throw "Comando falló ($LASTEXITCODE): $Exe"
  }
}

function Invoke-Psql {
  param([string]$Database, [string]$File)
  Invoke-Native -Exe $psql -Params @(
    '-X', '-w', '-v', 'ON_ERROR_STOP=1',
    '-h', '127.0.0.1', '-p', "$Port", '-U', 'postgres',
    '-d', $Database, '-f', $File
  )
}

function Invoke-PsqlCommand {
  param([string]$Database, [string]$Sql)
  Invoke-Native -Exe $psql -Params @(
    '-X', '-w', '-v', 'ON_ERROR_STOP=1',
    '-h', '127.0.0.1', '-p', "$Port", '-U', 'postgres',
    '-d', $Database, '-c', $Sql
  )
}

function Quote-ProcessArg {
  param([string]$Value)
  if ($Value -match '\s') {
    return '"' + $Value.Replace('"', '\"') + '"'
  }
  return $Value
}

function Start-PsqlProcess {
  param([string]$Database, [string]$File, [string]$Output)
  $params = @(
    '-X', '-w', '-v', 'ON_ERROR_STOP=1',
    '-h', '127.0.0.1', '-p', "$Port", '-U', 'postgres',
    '-d', $Database, '-f', $File
  )
  $argString = (@($params | ForEach-Object { Quote-ProcessArg $_ }) -join ' ')
  $errorPath = $Output + '.err'
  $process = Start-Process -FilePath $psql -ArgumentList $argString -RedirectStandardOutput $Output -RedirectStandardError $errorPath -PassThru
  return [pscustomobject]@{
    Process = $process
    Output = $Output
    Error = $errorPath
  }
}

function Assert-ProcessOk {
  param($Result, [string]$Name)
  $Result.Process.WaitForExit()
  $Result.Process.Refresh()
  $out = Get-Content -LiteralPath $Result.Output -Raw -ErrorAction SilentlyContinue
  $err = Get-Content -LiteralPath $Result.Error -Raw -ErrorAction SilentlyContinue
  if ($out) { Write-Output $out }
  if ($err) { Write-Output $err }
  if ($null -ne $Result.Process.ExitCode -and $Result.Process.ExitCode -ne 0) {
    throw "$Name terminó con código $($Result.Process.ExitCode)"
  }
}

$started = $false
try {
  Write-Output "BIN_DIR=$BinDir"
  Write-Output "PORT=$Port"
  Write-Output "RUN_DIR=$runDir"

  Invoke-Native -Exe $initdb -Params @('-A', 'trust', '-U', 'postgres', '-E', 'UTF8', '--no-instructions', '-D', $clusterDir)

  Invoke-Native -Exe $pgctl -Params @(
    '-D', $clusterDir, '-l', $logFile, '-w', 'start',
    '-o', "-p $Port -c listen_addresses=127.0.0.1 -c fsync=off -c synchronous_commit=off"
  )
  $started = $true

  $dbPrincipal = 'alerta_sismica_validacion_1'
  $dbReejecucion = 'alerta_sismica_validacion_2'

  Invoke-Native -Exe $createdb -Params @('-h', '127.0.0.1', '-p', "$Port", '-U', 'postgres', $dbPrincipal)
  Invoke-Native -Exe $createdb -Params @('-h', '127.0.0.1', '-p', "$Port", '-U', 'postgres', $dbReejecucion)

  $setup = Join-Path $testsDir '00_setup.sql'
  $migrations = Get-ChildItem -LiteralPath $migrationsDir -Filter '*.sql' | Sort-Object Name

  Write-Output 'PREPARANDO BASE PRINCIPAL'
  Invoke-Psql -Database $dbPrincipal -File $setup
  foreach ($migration in $migrations) {
    Write-Output "APLICANDO $($migration.Name)"
    Invoke-Psql -Database $dbPrincipal -File $migration.FullName
  }

  Write-Output 'PREPARANDO BASE DE REEJECUCION'
  Invoke-Psql -Database $dbReejecucion -File $setup
  foreach ($migration in $migrations) {
    Write-Output "APLICANDO 1x $($migration.Name)"
    Invoke-Psql -Database $dbReejecucion -File $migration.FullName
  }
  foreach ($migration in $migrations) {
    Write-Output "APLICANDO 2x $($migration.Name)"
    Invoke-Psql -Database $dbReejecucion -File $migration.FullName
  }

  Write-Output '=== VALIDACION PRINCIPAL ==='
  Invoke-Psql -Database $dbPrincipal -File (Join-Path $testsDir 'validacion.sql')

  Write-Output '=== REEJECUCION ==='
  Invoke-Psql -Database $dbReejecucion -File (Join-Path $testsDir 'reejecucion.sql')

  Write-Output '=== CONCURRENCIA REAL ENTRE DOS SESIONES ==='
  Invoke-PsqlCommand -Database $dbPrincipal -Sql 'select pruebas.reset();'

  $s1 = Start-PsqlProcess -Database $dbPrincipal -File (Join-Path $testsDir 'concurrencia_sesion1.sql') -Output (Join-Path $runDir 'concurrencia_s1.out')
  Start-Sleep -Milliseconds 700
  $s2 = Start-PsqlProcess -Database $dbPrincipal -File (Join-Path $testsDir 'concurrencia_sesion2.sql') -Output (Join-Path $runDir 'concurrencia_s2.out')

  Assert-ProcessOk -Result $s1 -Name 'SESION 1'
  Assert-ProcessOk -Result $s2 -Name 'SESION 2'

  Invoke-Psql -Database $dbPrincipal -File (Join-Path $testsDir 'concurrencia_verificacion.sql')

  Write-Output '=== RESUMEN ==='
  Write-Output 'MIGRACIONES: aplicadas en base limpia y reejecutadas en base separada'
  Write-Output 'VALIDACION: 24 pruebas SQL ejecutadas'
  Write-Output 'CONCURRENCIA: dos sesiones PostgreSQL independientes ejecutadas'
  Write-Output "LOG_POSTGRES=$logFile"
  Write-Output 'RESULTADO_FINAL=APROBADO'
} finally {
  if ($started) {
    Invoke-Native -Exe $pgctl -Params @('-D', $clusterDir, '-m', 'fast', '-w', 'stop') | Out-Null
  }
}
