$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$gcc = (Get-Command gcc -ErrorAction SilentlyContinue).Source
if (-not $gcc) {
    throw "gcc not found in PATH. Please install MinGW-w64 and make sure gcc is available."
}

Push-Location $root
try {
    & $gcc "cscheme.c" "-O0" "-lm" "-I." "-std=gnu89" "-o" "cscheme_win.exe"
    & $gcc "pre_passes.c" "hashcore_scmc.c" "-O0" "-lm" "-I." "-std=gnu89" "-o" "scmc2c_pre_pass_win.exe"
    & $gcc "fin_shell.c" "hashcore_scmc.c" "-O0" "-lm" "-I." "-std=gnu89" "-o" "scmc2c_multi_pass_win.exe"
}
finally {
    Pop-Location
}
