// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <string>
#ifdef _WIN32
#include <windows.h>
inline const HANDLE kInvalidFd = INVALID_HANDLE_VALUE;
using PipeHandle = HANDLE;
#else
inline const int kInvalidFd = -1;
using PipeHandle = int;
#endif

class Client;

class ClientLuaPipe
{
	Client *m_client;
	std::string m_path;
	PipeHandle m_fd;
	std::string m_buf;

	void processLine(const std::string &line);
	void writeResult(const std::string &file, bool ok, const std::string &content);

public:
	ClientLuaPipe(Client *client, const std::string &path);
	~ClientLuaPipe();
	void process();

	// Write a JSON command to the given pipe path.
	// Used by the --attach process to send core.reattach().
	static bool sendCommand(const std::string &pipe_path,
		const std::string &code, const std::string &response_file);
};
