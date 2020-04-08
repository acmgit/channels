local S = channels.S

minetest.register_chatcommand("channel", {
	description = S("Manages chat channels"),
	privs = {
		interact = true, 
		shout = true
	},
	func = function(name, param)
		if param == "" then
			minetest.chat_send_player(name, S("Online players:     /channel online"))
			minetest.chat_send_player(name, S("Join/switch:        /channel join <channel>"))
			minetest.chat_send_player(name, S("Leave channel:      /channel leave"))
			minetest.chat_send_player(name, S("Invite to channel:  /channel invite <playername>"))
			return

		elseif param == "online" then
			channels.command_online(name)
			return

		elseif param == "leave" then
			channels.command_leave(name)
			return
		end


		local args = param:split(" ")

		if args[1] == "join" and #args == 2 then
			channels.command_set(name, args[2])
			return

		elseif args[1] == "invite" and #args == 2 then
			channels.command_invite(name, args[2])
			return

		elseif args[1] == "wall" and #args >= 2 then
			channels.command_wall(name, table.concat(args," ",2, #args) )
			return
		end

		minetest.chat_send_player(name, S("Error: Please check again '/channel' for correct usage."))
	end,
})

function channels.say_chat(sendername, message, channel)
    -- For chat messages: 'message' must begin with '<playername>'
	-- if channel==nil then message is sent only to players in global chat

	minetest.log("action","CHAT: #" .. (channel or "no channel") .. " " .. message)

	local all_players = minetest.get_connected_players()

	for _,player in ipairs(all_players) do
		local playername = player:get_player_name()
		if channels.players[playername] == channel then
			minetest.chat_send_player(playername, message)
		end
	end
end

function channels.command_invite(hoster,guest)
	local channelname = channels.players[hoster]
	if not channelname then
		if channels.allow_global_channel then
			channelname = "the global chat"
		else
			minetest.chat_send_player(hoster, S("The global channel is not usable."))
			return
		end
	else
		channelname = "the '" .. channelname .. "' chat channel."
	end

	minetest.chat_send_player(guest, S("@1 invites you to join @2.", hoster, channelname))

	-- Let other players in channel know
	channels.say_chat(hoster,S("@1 invites @2 to join @3.",hoster,guest,channelname), channelname)
end

function channels.command_wall(name, message)
	local playerprivs = minetest.get_player_privs(name)
	if not playerprivs.basic_privs then
		minetest.chat_send_player(name, S("Error - require 'basic_privs' privilege."))
		return
	end

	minetest.chat_send_all(S("(Announcement from @1): @2", name, message))
end

function channels.command_online(name)
	local channel = channels.players[name]
	local list = {}
	if channel then
		for k, v in pairs(channels.players) do
			if v == channel then
				list[#list + 1] = k
			end
		end
	else -- global chat
		local oplayers = minetest.get_connected_players()
		for _, player in ipairs(oplayers) do
			local p_name = player:get_player_name()
			if not channels.players[p_name] then
				list[#list + 1] = p_name
			end
		end
	end
	
	minetest.chat_send_player(name, S("Online players in this channel: ")
		.. table.concat(list, ", "))
end

function channels.command_set(name, param)
	if param == "" then
		minetest.chat_send_player(name, S("Error: Empty channel name."))
		return
	end
	
	local channel_old = channels.players[name]
	if channel_old then
		if channel_old == param then
			minetest.chat_send_player(name, S("Error: You are already in this channel."))
			return
		end
		channels.say_chat(name, S("> @1 left the channel.", name), channel_old)
	else
		local oplayers = minetest.get_connected_players()
		for _,player in ipairs(oplayers) do
			local p_name = player:get_player_name()
			if not channels.players[p_name] and p_name ~= name and channels.allow_global_channel then
				minetest.chat_send_player(p_name, S("> @1 left the global chat.", name))
			end
		end
	end
	
	local player = minetest.get_player_by_name(name)
	if not player then
		return
	end
	
	if channels.huds[name] then
		player:hud_remove(channels.huds[name])
	end
	
	channels.players[name] = param
	channels.huds[name] = player:hud_add({
		hud_elem_type	= "text",
		name		= "Channel",
		number		= 0xFFFFFF,
		position	= {x = 0.6, y = 0.03},
		text		= S("Channel: ") .. param,
		scale		= {x = 200,y = 25},
		alignment	= {x = 0, y = 0},
	})
	channels.say_chat("",S("> @1 joined the channel.", name), param)
end

function channels.command_leave(name)
	local player = minetest.get_player_by_name(name)
	if not player then
		channels.players[name] = nil
		channels.huds[name] = nil
		return
	end
	
	if not (channels.players[name] and channels.huds[name]) then
		minetest.chat_send_player(name, S("Please join a channel first to leave it"))
		return
	end
	
	if channels.players[name] then
		channels.say_chat("",S("> @1 left the channel.", name), channels.players[name])
		channels.players[name] = nil
	end
	
	if channels.huds[name] then
		player:hud_remove(channels.huds[name])
		channels.huds[name] = nil
	end
end
