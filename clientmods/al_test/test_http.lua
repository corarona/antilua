-- Tests for CSM HTTP API

function test_http_api(T)
	T.defer("core.request_http_api exists", function()
		T.assert(type(core.request_http_api) == "function",
			"core.request_http_api should be a function")
	end)

	T.defer("core.request_http_api returns httpenv", function()
		local httpenv = core.request_http_api()
		T.assert(type(httpenv) == "table", "core.request_http_api() should return a table")
		T.assert(type(httpenv.fetch) == "function",
			"httpenv.fetch should be a function")
		T.assert(type(httpenv.fetch_async) == "function",
			"httpenv.fetch_async should be a function")
		T.assert(type(httpenv.fetch_async_get) == "function",
			"httpenv.fetch_async_get should be a function")
	end)

	T.defer("core.get_http_api exists", function()
		T.assert(type(core.get_http_api) == "function",
			"core.get_http_api should be a function")
	end)

	T.defer("core.get_http_api returns httpenv", function()
		local httpenv = core.get_http_api()
		T.assert(type(httpenv) == "table", "core.get_http_api() should return a table")
		T.assert(type(httpenv.fetch_async) == "function",
			"get_http_api httpenv.fetch_async should be a function")
		T.assert(type(httpenv.fetch_async_get) == "function",
			"get_http_api httpenv.fetch_async_get should be a function")
		T.assert(type(httpenv.fetch_sync) == "function",
			"get_http_api httpenv.fetch_sync should be a function")
	end)
end
