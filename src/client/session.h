// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <cstdint>
#include <ctime>
#include <string>
#ifdef _WIN32
#include <windows.h>
#endif

// Session file management for detach/re-attach.
// The session file lets a new antilua invocation discover a detached client.

namespace session {

// Session info read from the session file
struct Info {
	int pid = 0;
	std::string pipe_lua_path;
	uint64_t timestamp = 0;
};

// Path to the session directory: $XDG_RUNTIME_DIR/antilua/ or /tmp/antilua-$USER/
std::string getSessionDir();

#ifdef _WIN32
using pid_type = DWORD;
#else
using pid_type = pid_t;
#endif

// Write session file for the given PID and pipe_lua path.
void write(pid_type pid, const std::string &pipe_lua_path);

// Read session file, return Info with pid=0 if not found/valid.
Info read();

// Check whether a session is alive (file exists and PID is valid).
bool isLive();

// Remove the session file.
void remove();

} // namespace session
