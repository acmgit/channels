channels = {}
channels.huds = {}
channels.players = {}

channels.allow_global_channel = minetest.settings:get_bool("channels.allow_global_channel") ~= false
channels.disable_private_messages = minetest.settings:get_bool("channels.disable_private_messages") == true
channels.suggested_channel = minetest.settings:get("channels.suggested_channel")

local S

if(minetest.get_translator) then
    S = minetest.get_translator(minetest.get_current_modname())
else
    S = function(s) return s end
end

channels.S = S

dofile(minetest.get_modpath("channels") .. "/chatcommands.lua")




if channels.disable_private_messages then
    minetest.registered_chatcommands["msg"] = nil
end

local function remind_global_off()
	if not channels.allow_global_channel and channels.suggested_channel then
		channels.say_chat("*server*",
            S("<*server*> Out-of-channel chat is off.") .. 
            S("(try '/channel join ") .. channels.suggested_channel .. "' ?)"
        )
	end
end

if not channels.allow_global_channel then
	local global_inhibition_counter = 0 -- local to the file

	minetest.register_globalstep(function(dtime)
		global_inhibition_counter = global_inhibition_counter + dtime
		if global_inhibition_counter > 5*60 then
			global_inhibition_counter = 0
		else
			return
		end

		remind_global_off()
	end)
end

minetest.register_on_chat_message(function(name, message)
	local pl_channel = channels.players[name]

	if pl_channel == "" then
		channels.players[name] = nil
		pl_channel = nil
	end

	if not pl_channel then
		if not channels.allow_global_channel then
			minetest.chat_send_player(name, S("No channel selected. Run '/channel' for more info."))
			-- return true to prevent subsequent/global handler from kicking in
			return true
		else
			-- return false to indicate we have not handled the chat
			return false
		end
	end
	
	channels.say_chat(name, "<" .. name .. "> " .. message, pl_channel)
	return true
end)

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	channels.players[name] = nil
	channels.huds[name] = nil
end)
