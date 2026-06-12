// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "pipe_lua.h"
#include "client.h"
#include "script/scripting_client.h"

#include <json/json.h>

#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

#include <fstream>
#include <sstream>

ClientLuaPipe::ClientLuaPipe(Client *client, const std::string &path)
	: m_client(client), m_path(path), m_fd(-1)
{
	// Create FIFO; ignore EEXIST
	mkfifo(m_path.c_str(), 0666);

	m_fd = open(m_path.c_str(), O_RDONLY | O_NONBLOCK);
	if (m_fd < 0) {
		warningstream << "ClientLuaPipe: failed to open FIFO at "
			<< m_path << std::endl;
	}
}

ClientLuaPipe::~ClientLuaPipe()
{
	if (m_fd >= 0)
		close(m_fd);
	unlink(m_path.c_str());
}

void ClientLuaPipe::process()
{
	if (m_fd < 0)
		return;

	char buf[4096];
	ssize_t n = read(m_fd, buf, sizeof(buf) - 1);
	if (n <= 0)
		return;

	buf[n] = '\0';
	m_buf.append(buf, n);

	size_t pos;
	while ((pos = m_buf.find('\n')) != std::string::npos) {
		std::string line = m_buf.substr(0, pos);
		m_buf.erase(0, pos + 1);
		if (!line.empty())
			processLine(line);
	}
}

void ClientLuaPipe::writeResult(const std::string &file, bool ok,
	const std::string &content)
{
	std::ofstream ofs(file);
	if (!ofs) {
		warningstream << "ClientLuaPipe: cannot write to "
			<< file << std::endl;
		return;
	}
	ofs << (ok ? "ok" : "error") << std::endl;
	if (!content.empty())
		ofs << content << std::endl;
}

void ClientLuaPipe::processLine(const std::string &line)
{
	Json::Value root;
	Json::CharReaderBuilder builder;
	auto reader = std::unique_ptr<Json::CharReader>(builder.newCharReader());
	std::string json_errors;

	if (!reader->parse(line.data(), line.data() + line.size(),
			&root, &json_errors))
	{
		warningstream << "ClientLuaPipe: JSON parse error: "
			<< json_errors << std::endl;
		return;
	}

	if (!root.isMember("code")) {
		warningstream << "ClientLuaPipe: missing 'code' field" << std::endl;
		return;
	}

	std::string code = root["code"].asString();
	std::string response_file = root.get("file", "").asString();
	if (response_file.empty())
		response_file = "/tmp/antilua_lua_response";

	lua_State *L = m_client->getScript()->getLuaState();
	if (!L) {
		writeResult(response_file, false, "no Lua state available");
		return;
	}

	// Save stack top to distinguish return values from pre-existing state
	int top = lua_gettop(L);

	// Load code
	int load_result = luaL_loadstring(L, code.c_str());
	if (load_result != LUA_OK) {
		std::string err = lua_tostring(L, -1);
		lua_pop(L, 1);
		writeResult(response_file, false, err);
		return;
	}

	// Execute
	int pcrc = lua_pcall(L, 0, LUA_MULTRET, 0);
	if (pcrc != LUA_OK) {
		std::string err = lua_tostring(L, -1);
		lua_pop(L, 1);
		writeResult(response_file, false, err);
		return;
	}

	// Collect only the return values (items above the saved top)
	int nresults = lua_gettop(L) - top;
	if (nresults == 0) {
		writeResult(response_file, true, "");
		return;
	}

	std::ostringstream oss;
	for (int i = 1; i <= nresults; i++) {
		int idx = top + i;
		if (lua_isstring(L, idx) && !lua_isnumber(L, idx)) {
			oss << lua_tostring(L, idx);
		} else if (lua_isboolean(L, idx)) {
			oss << (lua_toboolean(L, idx) ? "true" : "false");
		} else if (lua_isnil(L, idx)) {
			oss << "nil";
		} else if (lua_isnumber(L, idx)) {
			oss << lua_tonumber(L, idx);
		} else {
			// Fallback: push tostring and call it
			lua_pushvalue(L, idx);
			lua_getglobal(L, "tostring");
			lua_pushvalue(L, -2);
			lua_call(L, 1, 1);
			oss << lua_tostring(L, -1);
			lua_pop(L, 2);
		}
		if (i < nresults)
			oss << std::endl;
	}

	lua_pop(L, nresults);

	writeResult(response_file, true, oss.str());
}
