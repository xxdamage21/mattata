--[[
    Copyright 2020 Matthew Hesketh <matthew@matthewhesketh.com>
    This code is licensed under the MIT. See LICENSE for details.
]]

local whitelistbot = {}
local mattata = require('mattata')
local redis = require('libs.redis')

function whitelistbot:init()
    whitelistbot.commands = mattata.commands(self.info.username):command('whitelistbot'):command('whitelistbots'):command('wb').table
    whitelistbot.help = '/whitelistbot <bots> - Whitelists the given bots in the current chat. Requires administrative privileges. Aliases: /whitelistbots, /wb.'
    whitelistbot.example_bots = { 'gif', 'imdb', 'wiki', 'music', 'youtube', 'bold', 'sticker', 'vote', 'like', 'gamee', 'coub', 'pic', 'vid', 'bing' }
end

function whitelistbot:on_new_message(message, configuration, language)
    if message.chat.type ~= 'supergroup' then
        return false
    elseif mattata.get_setting(message.chat.id, 'prevent inline bots') and message.via_bot and not mattata.is_group_admin(message.chat.id, message.from.id) then
        return mattata.delete_message(message.chat.id, message.message_id)
    end
end

function whitelistbot:on_message(message, configuration, language)
    if not mattata.is_group_admin(message.chat.id, message.from.id) then
        return mattata.send_reply(message, language.errors.admin)
    end
    local input = mattata.input(message.text)
    if not input then
        return mattata.send_reply(message, 'Please specify the @usernames of the bots you\'d like to whitelist.')
    elseif not input:match('@?[%w_]') then
        return mattata.send_reply(message, 'Please make sure you\'re specifying valid bot usernames!')
    end
    local bots = {}
    for bot in input:gmatch('@?([%w_]+bot)') do
        table.insert(bots, bot)
    end
    for _, bot in pairs(whitelistbot.example_bots) do
        if input:match('@?' .. bot) then
            table.insert(bots, bot)
        end
    end
    if #bots == 0 then
        return mattata.send_reply(message, 'Please make sure you\'re specifying valid bot usernames!')
    end
    for _, bot in pairs(bots) do
        redis:sadd('whitelisted_bots:' .. message.chat.id, bot)
    end
    local output = string.format('Successfully whitelisted the following bots in this chat: %s', table.concat(bots, ', '))
    return mattata.send_reply(message, output)
end

return whitelistbot