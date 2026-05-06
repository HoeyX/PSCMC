param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile,
    [Parameter(Position = 1)]
    [string]$Runtime = "C",
    [Parameter(Position = 2)]
    [string]$Mode = "device",
    [Parameter(Position = 3)]
    [string]$OutputFileName,
    [Parameter(Position = 4)]
    [string]$NamespacePrefix = ""
)

$ErrorActionPreference = "Stop"

if (-not $env:SCMC_COMPILE_ROOT) {
    throw "Environment variable SCMC_COMPILE_ROOT unspecified."
}

$compileRoot = $env:SCMC_COMPILE_ROOT
$cschemeWin = Join-Path $compileRoot "cscheme_win.exe"
$cschemeDefault = Join-Path $compileRoot "cscheme.exe"
$env:CSCHEME_EXEC = if (Test-Path $cschemeWin) { $cschemeWin } else { $cschemeDefault }
$env:STDLIB = Join-Path $compileRoot "stdlib.scm"

if (-not (Test-Path $env:CSCHEME_EXEC)) {
    throw "Missing executable: $env:CSCHEME_EXEC"
}

$output = [System.Text.RegularExpressions.Regex]::Replace($InputFile, '\.[^.\\\/]+$', '')
if ($Mode -eq "host") {
    $Mode = $Runtime
    $Runtime = "C"
}

switch ($Runtime) {
    "C" { $output = "$output.c" }
    "OpenMP" { $output = "$output.c" }
    "SWMC" { $output = "$output.c" }
    "COI" { $output = "$output.cpp" }
    "SYCL" { $output = "$output.cpp" }
    "OpenCL" { $output = "$output.ocl" }
    "CUDA" { $output = "$output.cu" }
    "HIP" { $output = "$output.cpp" }
    default { throw "Unsupported runtime: $Runtime" }
}

if ($OutputFileName) {
    $output = $OutputFileName
    $outputHeader = "$OutputFileName.def.ss"
} else {
    $outputHeader = "$output.def.ss"
}

if ($output -eq $InputFile) {
    throw "Invalid output name: $InputFile"
}

$inputContent = Get-Content -Raw $InputFile
$preexpandContent = "(define-scmc-global RUNTIME '$Runtime)`n$inputContent"
$preexpandBytes = [System.Text.Encoding]::UTF8.GetBytes($preexpandContent)

$psi1 = [System.Diagnostics.ProcessStartInfo]::new($env:CSCHEME_EXEC, "`"$compileRoot\preexpand.ss`"")
$psi1.WorkingDirectory = $compileRoot
$psi1.UseShellExecute = $false
$psi1.RedirectStandardInput = $true
$psi1.RedirectStandardOutput = $true
$psi1.RedirectStandardError = $true
$p1 = [System.Diagnostics.Process]::Start($psi1)
$p1.StandardInput.Write($preexpandContent)
$p1.StandardInput.Close()
$preexpanded = $p1.StandardOutput.ReadToEnd()
$err1 = $p1.StandardError.ReadToEnd()
$p1.WaitForExit()
if ($p1.ExitCode -ne 0) {
    throw "cscheme preexpand failed: $err1"
}

$prePassExe = Join-Path $compileRoot "scmc2c_pre_pass_win.exe"
if (-not (Test-Path $prePassExe)) {
    $prePassExe = Join-Path $compileRoot "scmc2c_pre_pass.exe"
}
$psi2 = [System.Diagnostics.ProcessStartInfo]::new($prePassExe, "$Runtime $Mode `"$NamespacePrefix`" - `"$outputHeader`" 2")
$psi2.WorkingDirectory = $compileRoot
$psi2.UseShellExecute = $false
$psi2.RedirectStandardInput = $true
$psi2.RedirectStandardOutput = $true
$psi2.RedirectStandardError = $true
$p2 = [System.Diagnostics.Process]::Start($psi2)
$writer2 = $p2.StandardInput
$writer2.WriteLine("1")
$writer2.Write($preexpanded)
$writer2.Close()
$prePassOutput = $p2.StandardOutput.ReadToEnd()
$err2 = $p2.StandardError.ReadToEnd()
$p2.WaitForExit()
if ($p2.ExitCode -ne 0) {
    throw "scmc2c_pre_pass failed: $err2"
}

$multiPassExe = Join-Path $compileRoot "scmc2c_multi_pass_win.exe"
if (-not (Test-Path $multiPassExe)) {
    $multiPassExe = Join-Path $compileRoot "scmc2c_multi_pass.exe"
}
$psi3 = [System.Diagnostics.ProcessStartInfo]::new($multiPassExe, "$Runtime $Mode `"$InputFile`" `"$output`"")
$psi3.WorkingDirectory = $compileRoot
$psi3.UseShellExecute = $false
$psi3.RedirectStandardInput = $true
$psi3.RedirectStandardError = $true
$p3 = [System.Diagnostics.Process]::Start($psi3)
$writer3 = $p3.StandardInput
$writer3.WriteLine("1")
$writer3.Write($prePassOutput)
$writer3.Close()
$err3 = $p3.StandardError.ReadToEnd()
$p3.WaitForExit()
if ($p3.ExitCode -ne 0) {
    throw "scmc2c_multi_pass failed: $err3"
}

if ((Test-Path $output) -and ((Get-Item $output).Length -gt 0)) {
    Write-Output $output
} else {
    if (Test-Path $output) {
        Remove-Item $output -Force
    }
    throw "Compilation produced an empty output file."
}
