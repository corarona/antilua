// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "pipe_lua.h"
#include "client.h"
#include "script/scripting_client.h"

#include <json/json.h>

#include <cmath>
#include <fstream>
#include <set>
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

// Serialize a Lua value to JSON (used when the 'serialize' request field is
// set). Tables are serialized recursively: arrays when the keys are contiguous
// integers 1..N, objects otherwise. Cycles and excessive nesting are guarded
// by an ancestor set and a depth limit. Userdata, functions and threads fall
// back to their tostring representation.
static void serializeLuaValue(lua_State *L, int idx, Json::Value &out,
	int depth, std::set<const void *> &ancestors)
{
	if (idx < 0)
		idx = lua_gettop(L) + idx + 1;

	if (depth > 32) {
		out = Json::nullValue;
		return;
	}

	if (lua_isnumber(L, idx)) {
		double num = lua_tonumber(L, idx);
		if (!std::isfinite(num)) {
			out = Json::nullValue;
		} else if (num == std::floor(num) &&
				num >= -9223372036854775808.0 &&
				num < 9223372036854775808.0) {
			// integral value: serialize as an integer, not "1.0"
			out = (Json::Value::Int64)num;
		} else {
			out = num;
		}
	} else if (lua_isboolean(L, idx)) {
		// lua_toboolean returns int in Lua 5.1; cast so JSON is true/false
		out = (lua_toboolean(L, idx) != 0);
	} else if (lua_isstring(L, idx)) {
		// lua_isstring also reports numbers, but those were handled above
		size_t len = 0;
		const char *str = lua_tolstring(L, idx, &len);
		out = std::string(str, len);
	} else if (lua_isnil(L, idx)) {
		out = Json::nullValue;
	} else if (lua_istable(L, idx)) {
		const void *ptr = lua_topointer(L, idx);
		if (ancestors.count(ptr) != 0) {
			out = Json::nullValue; // circular reference
			return;
		}
		ancestors.insert(ptr);

		// Determine whether the table is a sequence 1..n
		bool is_array = true;
		Json::UInt count = 0;
		Json::UInt max_index = 0;
		lua_pushnil(L);
		while (lua_next(L, idx) != 0) {
			// key is at -2, value at -1
			if (!lua_isnumber(L, -2)) {
				is_array = false;
			} else {
				double key_num = lua_tonumber(L, -2);
				if (key_num < 1.0 || std::floor(key_num) != key_num)
					is_array = false;
				Json::UInt key = (Json::UInt)key_num;
				if (key > max_index)
					max_index = key;
			}
			count++;
			lua_pop(L, 1);
		}
		if (count != max_index)
			is_array = false;

		if (is_array) {
			out = Json::arrayValue;
			out.resize(max_index);
			for (Json::UInt i = 1; i <= max_index; i++) {
				lua_rawgeti(L, idx, i);
				serializeLuaValue(L, -1, out[(Json::ArrayIndex)(i - 1)],
					depth + 1, ancestors);
				lua_pop(L, 1);
			}
		} else {
			out = Json::objectValue;
			lua_pushnil(L);
			while (lua_next(L, idx) != 0) {
				// key is at -2, value at -1
				// NOTE: never call lua_tolstring on the traversal key
				// directly: for numbers it converts the key in-place to a
				// string, so the next lua_next fails with
				// "invalid key to 'next'" (unprotected -> LUA PANIC).
				// Operate on a copy instead.
				std::string key;
				lua_pushvalue(L, -2); // copy of key
				size_t len = 0;
				const char *str = lua_tolstring(L, -1, &len);
				if (str) {
					key.assign(str, len);
					lua_pop(L, 1); // pop key copy
				} else {
					lua_pop(L, 1); // pop key copy
					// Non-string/number key (bool, table, ...):
					// fall back to tostring() via protected call.
					lua_pushvalue(L, -2); // copy of key
					lua_getglobal(L, "tostring");
					if (!lua_isfunction(L, -1)) {
						lua_pop(L, 2); // key copy + non-function
						key = "<non-string key>";
					} else {
						lua_pushvalue(L, -2); // key copy as arg
						if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
							lua_pop(L, 2); // key copy + error
							key = "<non-string key>";
						} else {
							size_t tlen = 0;
							const char *tstr =
								lua_tolstring(L, -1, &tlen);
							if (tstr)
								key.assign(tstr, tlen);
							else
								key = "<non-string key>";
							lua_pop(L, 1); // pop tostring result
							lua_pop(L, 1); // pop key copy
						}
					}
				}
				serializeLuaValue(L, -1, out[key], depth + 1, ancestors);
				lua_pop(L, 1);
			}
		}

		ancestors.erase(ptr);
	} else {
		// userdata, lightuserdata, function, thread: fall back to tostring
		// via protected call so a failing __tostring can't panic the client.
		lua_pushvalue(L, idx);
		lua_getglobal(L, "tostring");
		if (!lua_isfunction(L, -1)) {
			lua_pop(L, 2); // value copy + non-function
			out = Json::nullValue;
			return;
		}
		lua_pushvalue(L, -2); // value copy as arg
		if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
			lua_pop(L, 2); // value copy + error
			out = Json::nullValue;
			return;
		}
		size_t len = 0;
		const char *str = lua_tolstring(L, -1, &len);
		if (str)
			out = std::string(str, len);
		else
			out = Json::nullValue;
		lua_pop(L, 2);
	}
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
	bool serialize = root.get("serialize", false).asBool();
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
	if (serialize) {
		std::set<const void *> ancestors;
		if (nresults == 1) {
			serializeLuaValue(L, top + 1, root, 0, ancestors);
		} else {
			root = Json::arrayValue;
			for (int i = 1; i <= nresults; i++)
				serializeLuaValue(L, top + i, root[(Json::ArrayIndex)(i - 1)],
					0, ancestors);
		}
		Json::StreamWriterBuilder builder;
		builder["indentation"] = "";
		oss << Json::writeString(builder, root);
	} else {
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
				// Fallback: push tostring and call it (protected so a
				// failing __tostring can't panic the client).
				lua_pushvalue(L, idx);
				lua_getglobal(L, "tostring");
				if (!lua_isfunction(L, -1)) {
					lua_pop(L, 2);
					oss << "<unprintable>";
				} else {
					lua_pushvalue(L, -2);
					if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
						lua_pop(L, 2);
						oss << "<tostring error>";
					} else {
						const char *s = lua_tostring(L, -1);
						oss << (s ? s : "<unprintable>");
						lua_pop(L, 2);
					}
				}
			}
			if (i < nresults)
				oss << std::endl;
		}
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
