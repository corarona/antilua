// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "pipe_lua.h"
#include "client.h"
#include "script/scripting_client.h"

#include <json/json.h>

#include <fstream>
#include <sstream>

// Lua 5.1 compat: LUA_OK was introduced in 5.2
#ifndef LUA_OK
#define LUA_OK 0
#endif

#ifndef _WIN32
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#else
#include "filesys.h"
#endif

ClientLuaPipe::ClientLuaPipe(Client *client, const std::string &path)
	: m_client(client), m_path(path), m_fd(kInvalidFd)
{
#ifndef _WIN32
	// Create FIFO; ignore EEXIST
	mkfifo(m_path.c_str(), 0666);

	m_fd = open(m_path.c_str(), O_RDONLY | O_NONBLOCK);
	if (m_fd < 0) {
		warningstream << "ClientLuaPipe: failed to open FIFO at "
			<< m_path << std::endl;
	}
#else
	m_fd = CreateNamedPipeA(m_path.c_str(), PIPE_ACCESS_INBOUND,
		PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_NOWAIT,
		PIPE_UNLIMITED_INSTANCES, 4096, 4096, 0, nullptr);

	if (m_fd == INVALID_HANDLE_VALUE) {
		warningstream << "ClientLuaPipe: failed creating pipe at "
			<< m_path << std::endl;
	} else {
		ConnectNamedPipe(m_fd, nullptr);
	}
#endif
}

ClientLuaPipe::~ClientLuaPipe()
{
#ifndef _WIN32
	if (m_fd >= 0)
		close(m_fd);
	unlink(m_path.c_str());
#else
	if (m_fd != INVALID_HANDLE_VALUE) {
		DisconnectNamedPipe(m_fd);
		CloseHandle(m_fd);
	}
#endif
}

void ClientLuaPipe::process()
{
#ifndef _WIN32
	if (m_fd < 0)
		return;
#else
	if (m_fd == INVALID_HANDLE_VALUE)
		return;
#endif

	char buf[4096];

#ifdef _WIN32
	DWORD n = 0;
	BOOL ok = ReadFile(m_fd, buf, sizeof(buf) - 1, &n, nullptr);
	if (!ok) {
		if (GetLastError() == ERROR_BROKEN_PIPE) {
			DisconnectNamedPipe(m_fd);
			ConnectNamedPipe(m_fd, nullptr);
		}
		return;
	}

	if (n == 0)
		return;
#else
	ssize_t n = read(m_fd, buf, sizeof(buf) - 1);
	if (n <= 0)
		return;
#endif

	buf[n] = '\0';
	m_buf.append(buf, n);

	size_t pos;
	while ((pos = m_buf.find('\n')) != std::string::npos) {
		std::string line = m_buf.substr(0, pos);
		m_buf.erase(0, pos + 1);
#ifdef _WIN32
		while (!line.empty() && line.back() == '\r')
			line.pop_back();
#endif
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
	if (response_file.empty()) {
#ifdef _WIN32
		static const std::string fallback = fs::TempPath() + "\\antilua_lua_response";
	response_file = fallback;
#else
	response_file = "/tmp/antilua_lua_response";
#endif
	}

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

bool ClientLuaPipe::sendCommand(const std::string &pipe_path,
	const std::string &code, const std::string &response_file)
{
	Json::Value root;
	root["code"] = code;
	if (!response_file.empty())
		root["file"] = response_file;

	Json::StreamWriterBuilder builder;
	builder["indentation"] = "";
	std::string json = Json::writeString(builder, root) + "\n";

#ifndef _WIN32
	int fd = open(pipe_path.c_str(), O_WRONLY | O_NONBLOCK);
	if (fd < 0)
		return false;

	ssize_t written = write(fd, json.data(), json.size());
	close(fd);
	return written == (ssize_t)json.size();
#else
	HANDLE fd = CreateFileA(pipe_path.c_str(), GENERIC_WRITE,
		FILE_SHARE_READ | FILE_SHARE_WRITE,
		nullptr, OPEN_EXISTING, 0, nullptr);

	if (fd == INVALID_HANDLE_VALUE)
		return false;

	DWORD size = (DWORD)json.size();
	DWORD written = 0;
	BOOL ok = WriteFile(fd, json.data(), size, &written, nullptr);
	CloseHandle(fd);
	return ok && written == size;
#endif
}
