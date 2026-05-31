# lua_async

Coroutine-based async library for client-side mods. Provides cooperative multithreading with yield-based scheduling, task queues, and time-sliced iteration to avoid blocking the game loop.

Also exposed as `async` (same table).

## Player usage

No chat commands or cheats.

## API

- `async` / `lua_async` — Global table exposing all functions below.
- `async.Async()` — Factory returning a new async instance. Instance fields:
  - `maxtime` (default 200 ms) — max wall-clock per slice before yielding.
  - `queue_threads` (default 8) — max concurrent queue workers.
  - `iterate(from, to, func, callback)` — Iterate `from..to`, calling `func(i)` per step. Yields after `maxtime`.
  - `foreach(_pairs, func, callback)` — Iterate a table via `_pairs`, calling `func(k, v)`.
  - `do_while(condition_func, func, callback)` — Loop while `condition_func()` is truthy.
  - `register_globalstep(func)` — Register a persistent globalstep callback running in a coroutine.
  - `chain_task(tasks, callback)` — Run an array of functions sequentially, passing the return of each to the next.
  - `queue_task(func, callback)` — Enqueue a function for worker-thread execution.
  - `single_task(func, callback)` — Run a function once (no queue).
- `async.yield()` — Yield the current coroutine, resuming next globalstep.
- `async.sleep(ms)` — Suspend the current coroutine for `ms` milliseconds.

## Cheats

None. Library mod — no cheats registered.
