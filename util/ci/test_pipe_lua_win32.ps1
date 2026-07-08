# Test the Client Lua Pipe (named pipe IPC for client-side Lua execution) on windows
#
# Usage:
#   powershell -File ./util/ci/test_pipe_lua_win32.ps1

$ErrorActionPreference = "Stop"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$ROOT_DIR = Resolve-Path "$SCRIPT_DIR\..\.."
$PIPE_PATH = "\\.\pipe\antilua_lua_test"
$RESP_FILE = "$env:TEMP\antilua_lua_test_resp"
$CONFIG_FILE = "$env:TEMP\antilua_lua_test.conf"
$ESCAPED_RESP_FILE = $RESP_FILE -replace '\\', '\\\\'
$GAME_PROCESS = $null

# Sleeps for the specified number of milliseconds
function wait ($time) {
	Start-Sleep -Milliseconds $time
}

function cleanup {
	if ($null -ne $GAME_PROCESS) {
		try {
			if (!$GAME_PROCESS.HasExited) {
				Stop-Process -Id $GAME_PROCESS.Id -Force
			}
		} catch {}
	}

	Remove-Item $RESP_FILE -Force -ErrorAction SilentlyContinue
	Remove-Item $CONFIG_FILE -Force -ErrorAction SilentlyContinue
}

trap {
	echo $_
	cleanup
	exit 1
}

# Create config with pipe enabled
@"
pipe_lua_enable = true
pipe_lua_path = $PIPE_PATH
"@ | Out-File -Encoding ascii $CONFIG_FILE

echo "=== Client Lua Pipe Test ==="

# Start game
echo "Starting game..."

$GAME_PROCESS = Start-Process `
	-FilePath "$ROOT_DIR\bin\antilua.exe" -WorkingDirectory "$ROOT_DIR\bin" `
	-ArgumentList @("--info", "--gameid", "devtest",
	"--world", "$ROOT_DIR\worlds\test_df",
	"--go", "--config", $CONFIG_FILE) -PassThru

wait 2000
if ($GAME_PROCESS.HasExited) {
	echo "FAIL: game exited immediately"
	exit 1
}

function send ([string]$Code) {
	Invoke-Expression ('cmd.exe --% /c (echo {"code":"' + $Code + '","file":"' `
			+ $ESCAPED_RESP_FILE + '"})>' + $PIPE_PATH)
}

function read {
	try {
		$text = Get-Content $RESP_FILE -Raw -Encoding UTF8
		return ($text -replace "`r", "").TrimEnd()
	} catch {}
	return "timeout"
}

$PASS_COUNT = 0
$FAIL_COUNT = 0

function check($name, $expected, $actual) {
	if ($actual.Trim() -eq $expected.Trim()) {
		echo "  PASS: $name"
		$script:PASS_COUNT++
	} else {
		echo "  FAIL: $name"
		echo "    expected: $expected"
		echo "    got:      $actual"
		$script:FAIL_COUNT++
	}
}

# Wait for the pipe to appear (up to 30 seconds)
echo "Waiting for pipe..."
for ($i = 0; $i -lt 300; $i++) {
	if (Test-Path $PIPE_PATH) {
		echo "Pipe connected"
		break
	}
	wait 100
}

# Generously wait a little more since can be busy on startup
wait 1000

if (-not (Test-Path $PIPE_PATH)) {
	throw "FAIL: Pipe was not created within 30 seconds."
}

# Test 1: simple arithmetic expression
send "return 1+1"
wait 500
check "simple expression" "ok`n2" (read)

# Test 2: error handling
send "error('test error')"
wait 500
$RESULT = read
if ($RESULT -match "^error") {
	echo "  PASS: error handling"
	$PASS_COUNT++
} else {
	echo "  FAIL: error handling"
	echo "    expected: error/..."
	echo "    got:      $RESULT"
	$FAIL_COUNT++
}

# Test 3: string result
send "return 'hello'"
wait 500
check "string result" "ok`nhello" (read)

# Test 4: boolean results
send "return true, false"
wait 500
check "boolean results" "ok`ntrue`nfalse" (read)

# Test 5: nil result
send "return nil"
wait 500
check "nil result" "ok`nnil" (read)

# Test 6: no return value
send "local x = 1"
wait 500
check "no return value" "ok" (read)

# Test 7: table serialization via tostring
send "return {1,2,3}"
wait 500
$RESULT = read
if (($RESULT -split "`n")[0] -eq "ok") {
	echo "  PASS: table result"
	$PASS_COUNT++
} else {
	echo "  FAIL: table result"
	echo "    got: $RESULT"
	$FAIL_COUNT++
}

echo ""
echo "=== Results: $PASS_COUNT passed, $FAIL_COUNT failed ==="
cleanup

if ($FAIL_COUNT -eq 0) {
	exit 0
}  
exit 1
