local builtin_shared = ...

local make_registration = builtin_shared.make_registration

-- Use local registration to avoid overwriting client-side formspec handlers
local pause_formspec_table, pause_register_formspec = make_registration()
