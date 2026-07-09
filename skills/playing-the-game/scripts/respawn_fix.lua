-- Send the death formspec response to trigger server-side respawn
core.send_inventory_fields("__builtin:death", {quit = "true"})
return "sent death formspec quit"
