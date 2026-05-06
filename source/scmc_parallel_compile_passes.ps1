param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile,
    [Parameter(Position = 1)]
    [string]$Parallel = "OpenMP",
    [Parameter(Position = 2)]
    [string]$Prefix = ""
)

$ErrorActionPreference = "Stop"

if (-not $env:SCMC_COMPILE_ROOT) {
    throw "Environment variable SCMC_COMPILE_ROOT unspecified."
}

$compileRoot = $env:SCMC_COMPILE_ROOT
$env:SCMC_ROOT = Join-Path $compileRoot "runtime_passes"
$compileScript = Join-Path $compileRoot "scmc_compile_passes.ps1"
function Convert-ToSchemePath([string]$pathValue) {
    return $pathValue -replace '\\', '/'
}

switch ($Parallel) {
    "OpenMP" { $fileExt = "c"; $lcName = "openmp"; $runtimeExt = "c" }
    "COI" { $fileExt = "cpp"; $lcName = "coi"; $runtimeExt = "cpp" }
    "SYCL" { $fileExt = "cpp"; $lcName = "sycl"; $runtimeExt = "cpp" }
    "C" { $fileExt = "c"; $lcName = "c"; $runtimeExt = "c" }
    "SWMC" { $fileExt = "c"; $lcName = "swmc"; $runtimeExt = "c" }
    "OpenCL" { $fileExt = "ocl"; $lcName = "opencl"; $runtimeExt = "c" }
    "CUDA" { $fileExt = "cu"; $lcName = "cuda"; $runtimeExt = "cu" }
    "HIP" { $fileExt = "cpp"; $lcName = "hip"; $runtimeExt = "cpp" }
    default { throw "Unsupported runtime: $Parallel" }
}

if (-not (Test-Path $InputFile)) {
    throw "$InputFile not exist"
}

$baseName = [System.Text.RegularExpressions.Regex]::Replace($InputFile, '\.[^.\\\/]+$', '')
$kernelOutput = "$baseName.$fileExt"
& powershell -ExecutionPolicy Bypass -File $compileScript $InputFile $Parallel "device" $kernelOutput $Prefix

$cDefSs = "$kernelOutput.def.ss"
if (-not (Test-Path $cDefSs)) {
    throw "$cDefSs not exist"
}
$cDefSsScheme = Convert-ToSchemePath $cDefSs

$inputInch = "${baseName}_inc.scmc"
$outputInch = "${baseName}_inc.h"
$outputInchScheme = Convert-ToSchemePath $outputInch
$kernelOutputScheme = Convert-ToSchemePath $kernelOutput
$runtimeHeader = Get-Content -Raw (Join-Path $env:SCMC_ROOT "${lcName}_runtime_h.scmc")
$headerContent = @"
(define-scmc-global kfunlist (let ((fp1 (open-input-file "$cDefSsScheme"))) (read fp1) (read fp1)))
(define-scmc-global PREFIX "$Prefix")
$runtimeHeader
"@
Set-Content -Path $inputInch -Value $headerContent -Encoding UTF8
& powershell -ExecutionPolicy Bypass -File $compileScript $inputInch "C" "host" $outputInch

$inputRuntime = "${baseName}_runtime.scmc"
$runtimeBody = Get-Content -Raw (Join-Path $env:SCMC_ROOT "${lcName}_runtime.scmc")
$runtimeContent = @"
(define-scmc-global kfunlist (let ((fp1 (open-input-file "$cDefSsScheme"))) (read fp1) (read fp1)))
(define-scmc-global headfile_name "$outputInchScheme")
(define-scmc-global sourcefile "$kernelOutputScheme")
(define-scmc-global PREFIX "$Prefix")
$runtimeBody
"@
Set-Content -Path $inputRuntime -Value $runtimeContent -Encoding UTF8
$runtimeOutput = "${baseName}_runtime.$runtimeExt"
& powershell -ExecutionPolicy Bypass -File $compileScript $inputRuntime "C" "host" $runtimeOutput

Write-Output $runtimeOutput
