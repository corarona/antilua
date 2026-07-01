// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "session.h"
#include "filesys.h"
#include "log.h"
#include "porting.h"

#include <json/json.h>

#include <fstream>
#include <sstream>
#include <cstdlib>

namespace session {

std::string getSessionDir()
{
	// Try XDG_RUNTIME_DIR first
	const char *runtime = std::getenv("XDG_RUNTIME_DIR");
	if (runtime && runtime[0])
		return std::string(runtime) + "/antilua";

	// Fallback to /tmp/antilua-$USER
	const char *user = std::getenv("USER");
	if (user && user[0])
		return std::string("/tmp/antilua-") + user;

	return "/tmp/antilua";
}

static std::string sessionFilePath()
{
	return getSessionDir() + "/session";
}

void write(int pid, const std::string &pipe_lua_path)
{
	std::string dir = getSessionDir();
	if (!fs::CreateAllDirs(dir)) {
		warningstream << "session: cannot create directory "
			<< dir << std::endl;
		return;
	}

	Json::Value root;
	root["pid"] = (Json::Value::Int64)pid;
	root["pipe_lua_path"] = pipe_lua_path;
	root["timestamp"] = (Json::Value::UInt64)std::time(nullptr);

	Json::StreamWriterBuilder builder;
	builder["indentation"] = "";
	std::string json = Json::writeString(builder, root) + "\n";

	std::ofstream ofs(sessionFilePath());
	if (ofs)
		ofs << json;
	else
		warningstream << "session: cannot write " << sessionFilePath() << std::endl;
}

Info read()
{
	Info info;

	std::ifstream ifs(sessionFilePath());
	if (!ifs)
		return info;

	Json::Value root;
	Json::CharReaderBuilder builder;
	std::string errs;
	if (!Json::parseFromStream(builder, ifs, &root, &errs)) {
		warningstream << "session: parse error: " << errs << std::endl;
		return info;
	}

	info.pid = root.get("pid", 0).asInt();
	info.pipe_lua_path = root.get("pipe_lua_path", "").asString();
	info.timestamp = root.get("timestamp", 0).asUInt64();
	return info;
}

bool isLive()
{
	Info info = read();
	if (info.pid <= 0)
		return false;
	return porting::pid_alive(info.pid);
}

void remove()
{
	std::string path = sessionFilePath();
	// Don't warn on ENOENT
	// Only warn on non-ENOENT errors
	if (fs::PathExists(path) && !fs::DeleteSingleFileOrEmptyDirectory(path, false))
		warningstream << "session: cannot remove " << path << std::endl;
}

} // namespace session
