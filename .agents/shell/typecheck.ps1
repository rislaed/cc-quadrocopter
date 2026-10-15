$projectRoot = (Resolve-Path "$PSScriptRoot\..\..").Path

$extDirs = @(
	(Join-Path $env:USERPROFILE ".vscode\extensions"),
	(Join-Path $env:USERPROFILE ".vscode-insiders\extensions")
)

$serverExe = $null

foreach ($extDir in $extDirs) {
	if (Test-Path $extDir) {
		$luaExtDirs = Get-ChildItem -Path $extDir -Directory -Filter "*lua*" -ErrorAction SilentlyContinue
		foreach ($luaDir in $luaExtDirs) {
			$candidate1 = Join-Path $luaDir.FullName "server\bin\lua-language-server.exe"
			if (Test-Path $candidate1) {
				$serverExe = $candidate1
				break
			}
			$candidate2 = Join-Path $luaDir.FullName "bin\lua-language-server.exe"
			if (Test-Path $candidate2) {
				$serverExe = $candidate2
				break
			}
		}
		if ($serverExe) { break }
	}
}

if (-not $serverExe) {
	$cmd = Get-Command "lua-language-server" -ErrorAction SilentlyContinue
	if ($cmd) {
		$serverExe = $cmd.Source
	}
}

if (-not $serverExe) {
	Write-Error "lua-language-server.exe not found in *lua* VS Code extensions or PATH."
	exit 1
}

& $serverExe --check="$projectRoot" --configpath="$projectRoot\.luarc.json"
