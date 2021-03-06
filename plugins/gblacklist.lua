--[[
    Copyright 2020 Matthew Hesketh <matthew@matthewhesketh.com>
    This code is licensed under the MIT. See LICENSE for details.
]]

local gblacklist = {}
local mattata = require('mattata')
local redis = require('libs.redis')

function gblacklist:init()
    gblacklist.commands = mattata.commands(self.info.username):command('gblacklist').table
end

function gblacklist:on_message(message, configuration, language)
    local input = mattata.input(message.text)
    if not mattata.is_global_admin(message.from.id) then
        return
    elseif not message.reply and not input then
        return mattata.send_reply(message, language['gblacklist']['1'])
    elseif message.reply then
        input = message.reply.from.id
    end
    if tonumber(input) == nil and not input:match('^@') then
        input = '@' .. input
    end
    local resolved = mattata.get_user(input)
    local output
    if not resolved then
        output = string.format(language['gblacklist']['2'], input)
        return mattata.send_reply(message, output)
    elseif resolved.result.type ~= 'private' then
        output = string.format(language['gblacklist']['3'], resolved.result.type)
        return mattata.send_reply(message, output)
    end
    if resolved.result.id == self.info.id or mattata.is_global_admin(resolved.result.id) then
        return
    end
    redis:set('global_blacklist:' .. resolved.result.id, true)
    output = string.format('%s [%s] has blacklisted %s [%s] from using %s.', message.from.first_name, message.from.id, resolved.result.first_name, resolved.result.id, self.info.first_name)
    if configuration.log_admin_actions and configuration.log_channel ~= '' then
        mattata.send_message(configuration.log_channel, '<pre>' .. mattata.escape_html(output) .. '</pre>', 'html')
    end
    return mattata.send_message(message.chat.id, '<pre>' .. mattata.escape_html(output) .. '</pre>', 'html')
end

return gblacklist