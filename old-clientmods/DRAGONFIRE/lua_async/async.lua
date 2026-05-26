local threads = {}
local time = 0
minetest.register_globalstep(function(dtime)
	time = time + dtime
	if #threads < 1 then
		return
	end
	for i = #threads, 1, -1 do
		if time >= threads[i].delay then
			local thread = threads[i].thread
			local state = coroutine.status(thread)
			if state == "dead" then
				table.remove(threads, i)
			elseif state == "suspended" then
				coroutine.resume(thread)
				threads[i].delay = time + threads[i].delaymax
			end
		end
	end
end)

function async.Async()
	local self = {}
	self.task_queue = {}
	self.maxtime = 200
	self.queue_threads = 8
	self.create_worker = function(func)
		local thread = coroutine.create(func)
		if not thread or coroutine.status(thread) == "dead" then
			minetest.after(0.5, self.create_worker, func)
			return
		end
		threads[#threads + 1] = {
			thread = thread,
			delay = time + self.maxtime / 1000,
			delaymax = self.maxtime / 1000
		}
	end
	self.create_globalstep_worker = function(func)
		local thread = coroutine.create(func)
		if not thread or coroutine.status(thread) == "dead" then
			minetest.after(0.5, self.create_globalstep_worker, func)
			return
		end
		threads[#threads + 1] = {
			thread = thread,
			delay = time,
			delaymax = 0
		}
	end
	self.iterate = function(from, to, func, callback)
		self.create_worker(function()
			local last_time = minetest.get_us_time() / 1000
			local maxtime = self.maxtime
			for i = from, to do
				local b = func(i)
				if b ~= nil and b == false then
					break
				end
				if minetest.get_us_time() / 1000 > last_time + maxtime then
					coroutine.yield()
					last_time = minetest.get_us_time() / 1000
				end
			end
			if callback then
				callback()
			end
			return
		end)
	end
	self.foreach = function(_pairs, func, callback)
		self.create_worker(function()
			local last_time = minetest.get_us_time() / 1000
			local maxtime = self.maxtime
			for k, v in _pairs do
				local b = func(k, v)
				if b ~= nil and b == false then
					break
				end
				if minetest.get_us_time() / 1000 > last_time + maxtime then
					coroutine.yield()
					last_time = minetest.get_us_time() / 1000
				end
			end
			if callback then
				callback()
			end
			return
		end)
	end
	self.do_while = function(condition_func, func, callback)
		self.create_worker(function()
			local last_time = minetest.get_us_time() / 1000
			local maxtime = self.maxtime
			while(condition_func()) do
				local c = func()
				if c ~= nil and c ~= condition_func() then
					break
				end
				if minetest.get_us_time() / 1000 > last_time + maxtime then
					coroutine.yield()
					last_time = minetest.get_us_time() / 1000
				end
			end
			if callback then
				callback()
			end
			return
		end)
	end
	self.register_globalstep = function(func)
		self.create_globalstep_worker(function()
			local last_time = minetest.get_us_time() / 1000000
			local dtime = last_time
			while(true) do
				dtime = (minetest.get_us_time() / 1000000) - last_time
				func(dtime)
				-- 0.05 seconds
				if minetest.get_us_time() / 1000000 > last_time + 0.05 then
					coroutine.yield()
					last_time = minetest.get_us_time() / 1000000
				end
			end
		end)
	end
	self.chain_task = function(tasks, callback)
		self.create_worker(function()
			local pass_arg = nil
			local last_time = minetest.get_us_time() / 1000
			local maxtime = self.maxtime
			for index, task_func in pairs(tasks) do
				local p = task_func(pass_arg)
				if p ~= nil then
					pass_arg = p
				end
				if minetest.get_us_time() / 1000 > last_time + maxtime then
					coroutine.yield()
					last_time = minetest.get_us_time() / 1000
				end
			end
			if callback then
				callback(pass_arg)
			end
			return
		end)
	end
	self.queue_task = function(func, callback)
		table.insert(self.task_queue, {func = func, callback = callback})
		if self.queue_threads > 0 then
			self.queue_threads = self.queue_threads - 1
			self.create_worker(function()
				local pass_arg = nil
				local last_time = minetest.get_us_time() / 1000
				local maxtime = self.maxtime
				while(true) do
					local task_func = self.task_queue[#self.task_queue]
					self.task_queue[#self.task_queue] = nil
					if task_func and task_func.func then
						pass_arg = nil
						local p = task_func.func()
						if p ~= nil then
							pass_arg = p
						end
						if task_func.callback then
							task_func.callback(pass_arg)
						end
						if minetest.get_us_time() / 1000 > last_time + maxtime then
							coroutine.yield()
							last_time = minetest.get_us_time() / 1000
						end
					else
						self.queue_threads = self.queue_threads + 1
						return
					end
				end
			end)
		end
	end
	self.single_task = function(func, callback)
		self.create_worker(function()
			local pass_arg = func()
			if p ~= nil then
				pass_arg = p
			end
			if task_func.callback then
				task_func.callback(pass_arg)
			end
			return
		end)
	end
	return self
end
