# build-progress.ps1 - shows two progress bars while "cabal build" is running:
#   1. how many libraries are finished,
#   2. inside the library being compiled now: which file ("module") it is on.
# Run it from this folder with:   powershell -ExecutionPolicy Bypass -File .\build-progress.ps1
# Add -Once to print one line of text instead of live bars. Press Ctrl+C to stop.
param([switch]$Once)

$planFile = Join-Path $PSScriptRoot 'dist-newstyle\cache\plan.json'
if (-not (Test-Path $planFile)) { Write-Host 'No build plan yet: run "cabal build" first.'; exit }
$plan     = Get-Content $planFile -Raw | ConvertFrom-Json
$compiler = $plan.'compiler-id'                                   # e.g. ghc-9.10.3
# Libraries to build = everything your site program needs, directly or indirectly.
$byId = @{}; foreach ($u in $plan.'install-plan') { $byId[$u.id] = $u }
$needed = @{}; $queue = New-Object System.Collections.Queue
$plan.'install-plan' | Where-Object { $_.style -eq 'local' } | ForEach-Object { $queue.Enqueue($_.id) }
while ($queue.Count) {
  $u = $byId[$queue.Dequeue()]
  if (-not $u) { continue }
  $deps = @($u.depends) + @($u.'exe-depends')
  if ($u.components) { foreach ($c in $u.components.PSObject.Properties) {
      $deps += @($c.Value.depends) + @($c.Value.'exe-depends') } }
  foreach ($d in $deps) { if ($d -and -not $needed.ContainsKey($d)) { $needed[$d] = 1; $queue.Enqueue($d) } }
}
$ids = @($needed.Keys | Where-Object { $byId[$_].type -eq 'configured' -and $byId[$_].style -eq 'global' })
$cabalDir = Join-Path $env:LOCALAPPDATA 'cabal'
$store    = Get-ChildItem (Join-Path $cabalDir 'store') -Directory |
              Where-Object { $_.Name -like "$compiler*" } | Select-Object -First 1
$logs     = Join-Path $cabalDir "logs\$compiler"

while ($true) {
  $done  = @($ids | Where-Object { $store -and (Test-Path (Join-Path $store.FullName $_)) }).Count
  $total = [Math]::Max($ids.Count, 1)

  # The library being compiled now = the log file written to in the last minute.
  $current = $null; $x = 0; $y = 0; $module = ''
  $log = Get-ChildItem $logs -Filter *.log -ErrorAction SilentlyContinue |
           Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-1) } |
           Sort-Object LastWriteTime | Select-Object -Last 1
  if ($log) {
    $current = $log.BaseName -replace '-[0-9a-f]{20,}$', ''
    $m = Get-Content $log.FullName -Tail 30 | Select-String '\[\s*(\d+) of (\d+)\] Compiling (\S+)' |
           Select-Object -Last 1
    if ($m) { $x = [int]$m.Matches[0].Groups[1].Value; $y = [int]$m.Matches[0].Groups[2].Value
              $module = $m.Matches[0].Groups[3].Value }
  }

  if ($Once) {
    $line = "Libraries: $done of $total finished."
    if ($current) { $line += " Now compiling $current" ; if ($y) { $line += ": module $x of $y ($module)" } }
    Write-Host $line; break
  }

  Write-Progress -Id 1 -Activity 'Building Haskell libraries' `
                 -Status "$done of $total finished" -PercentComplete (100 * $done / $total)
  if ($current -and $y) {
    Write-Progress -Id 2 -ParentId 1 -Activity "Compiling $current" `
                   -Status "module $x of $y : $module" -PercentComplete (100 * $x / $y)
  } else {
    Write-Progress -Id 2 -ParentId 1 -Activity 'Compiling' -Status ($(if ($current) { $current } else { '...' }))
  }

  if (-not (Get-Process cabal -ErrorAction SilentlyContinue)) {
    Write-Progress -Id 1 -Activity 'Building Haskell libraries' -Completed
    Write-Host "cabal has stopped. Libraries finished: $done of $total."; break
  }
  Start-Sleep -Seconds 2
}
