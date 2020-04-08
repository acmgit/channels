local S = channels.S

minetest.register_chatcommand("c", {
	description = S("Manages chat channels"),
	privs = {
		interact = true, 
		shout = true
	},
	func = function(name, param)
		if param == "" then
			minetest.chat_send_player(name, S("Online players:     /c online"))
			minetest.chat_send_player(name, S("Join/switch:        /c join <channel>"))
			minetest.chat_send_player(name, S("Leave channel:      /c leave"))
			minetest.chat_send_player(name, S("Invite to channel:  /c invite <playername>"))
            minetest.chat_send_player(name, S("List channels:      /c list"))
			minetest.chat_send_player(name, S("Send all:           /c all <message>"))
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

		elseif args[1] == "all" and #args >= 2 then
			channels.command_wall(name, table.concat(args," ",2, #args) )
			return
                                         
        elseif args[1] == "list" then
            channels.command_list_channels(name)
            return
		end

		minetest.chat_send_player(name, channels.red .. S("Error: Please check again '/c' for correct usage."))
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
			minetest.chat_send_player(hoster, channels.red .. S("The global channel is not usable."))
			return
		end
	else
		channelname = "the '" .. channelname .. "' chat channel."
	end

	minetest.chat_send_player(guest,channels.orange .. S("@1 invites you to join @2. Enter /c join @2 to join.", hoster, channelname))

	-- Let other players in channel know
	channels.say_chat(hoster,channels.green .. S("@1 invites @2 to join @3.",hoster,guest,channelname), channelname)
end

function channels.command_wall(name, message)
	local playerprivs = minetest.get_player_privs(name)
	if not playerprivs.basic_privs then
		minetest.chat_send_player(name,channels.red .. S("Error - require 'basic_privs' privilege."))
		return
	end

	minetest.chat_send_all(channels.green .. "[" .. channels.yellow .. name .. channels.green .. "]: " .. channels.orange .. message)
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
	
	minetest.chat_send_player(name, channels.green .. S("Online players in this channel: ") .. channels.orange
		.. table.concat(list, ", "))
end

function channels.command_set(name, param)
	if param == "" then
		minetest.chat_send_player(name, channels.red .. S("Error: Empty channel name."))
		return
	end
	
	local channel_old = channels.players[name]
	if channel_old then
		if channel_old == param then
			minetest.chat_send_player(name, channels.red .. S("Error: You are already in this channel."))
			return
		end
		channels.say_chat(name, channels.orange .. S("> @1 left the channel.", name), channel_old)
	else
		local oplayers = minetest.get_connected_players()
		for _,player in ipairs(oplayers) do
			local p_name = player:get_player_name()
			if not channels.players[p_name] and p_name ~= name and channels.allow_global_channel then
				minetest.chat_send_player(p_name, channels.orange .. S("> @1 left the global chat.", name))
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
		text		= channels.green .. S("Channel: ").. channels.orange .. param,
		scale		= {x = 200,y = 25},
		alignment	= {x = 0, y = 0},
	})
	channels.say_chat("",channels.orange .. S("> @1 joined the channel.", name), param)
end

function channels.command_leave(name)
	local player = minetest.get_player_by_name(name)
	if not player then
		channels.players[name] = nil
		channels.huds[name] = nil
		return
	end
	
	if not (channels.players[name] and channels.huds[name]) then
		minetest.chat_send_player(name, channels.red .. S("Please join a channel first to leave it"))
		return
	end
	
	if channels.players[name] then
		channels.say_chat("",channels.orange .. S("> @1 left the channel.", name), channels.players[name])
		channels.players[name] = nil
	end
	
	if channels.huds[name] then
		player:hud_remove(channels.huds[name])
		channels.huds[name] = nil
	end
end

function channels.command_list_channels(name)
    
    minetest.chat_send_player(name, channels.green .. S("Available Channels:"))
    local list = {}
    
    for _,value in pairs(channels.players) do
            if value ~= "" then
                list[value] = value
            end
    end
    
    if(list ~= nil) then
        for _,value in pairs(list) do
            minetest.chat_send_player(name, channels.orange .. value)
        end
    end
    
end
