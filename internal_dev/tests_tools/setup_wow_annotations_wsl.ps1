[CmdletBinding()]
param(
    [string]$WslDistribution = "Ubuntu-26.04"
)

$ErrorActionPreference = "Stop"

function Invoke-Wsl {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Label
    )

    & wsl.exe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

Write-Output "==> Installing WSL build prerequisites"
Invoke-Wsl -Label "WSL prerequisite installation" -Arguments @(
    "-d", $WslDistribution, "-u", "root", "--", "bash", "-lc",
    "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential python3-pip python3-venv libreadline-dev unzip libssl-dev"
)

Write-Output "==> Installing the self-contained Lua annotation toolchain"
$setup = @'
set -eu
mkdir -p ~/.local/share/lstweeks-ketho
setup_dir=$(mktemp -d)
trap 'rm -rf "$setup_dir"' EXIT
python3 -m venv "$setup_dir/venv"
. "$setup_dir/venv/bin/activate"
pip install 'git+https://github.com/luarocks/hererocks@5d77b0bafc8b96f82355ca2ce5637c00d78a065c'
hererocks ~/.local/share/lstweeks-ketho/.lua -l 5.4.9 -r 3.13.0
. ~/.local/share/lstweeks-ketho/.lua/bin/activate
luarocks install luafilesystem 1.9.0-1
luarocks install lua-path 0.3.1-2
luarocks install luasocket 3.1.0-1
luarocks install luasec 1.3.2-1
luarocks install xml2lua 1.6-2
luarocks install lua-cjson 2.1.0.10-1
'@
Invoke-Wsl -Label "Lua annotation toolchain installation" -Arguments @(
    "-d", $WslDistribution, "--", "bash", "-lc", $setup
)

Write-Output "WSL annotation toolchain is ready."
