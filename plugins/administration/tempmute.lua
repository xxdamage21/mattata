--[[
    Copyright 2020 Matthew Hesketh <matthew@matthewhesketh.com>
    This code is licensed under the MIT. See LICENSE for details.
]]

local tempmute = {}
local mattata = require('mattata')

function tempmute:init()
    tempmute.commands = mattata.commands(self.info.username):command('tempmute').table
    tempmute.help = '/tempmute [user] <length> - Temporarily mutes a user in the current chat for the given length. The length should be in the format 1y2mo3w4d5h6m7s. Some natural language is supported too. Temp-mutes must be a minimum of 60 seconds in length. This command can only be used by moderators and administrators of a supergroup.'
end

function tempmute:on_message(message, configuration, language)
    if message.chat.type ~= 'supergroup' then
        local output = language['errors']['supergroup']
        return mattata.send_reply(message, output)
    elseif not mattata.is_group_admin(message.chat.id, message.from.id) then
        local output = language['errors']['admin']
        return mattata.send_reply(message, output)
    end
    local user, until_date = false, false
    local input = mattata.input(message)
    if input:match('^@?[%w_]+ .-$') then
        user, until_date = input:match('^(@?[%w_]+) (.-)$')
    elseif input then
        until_date = input
        if message.reply then
            user = message.reply.from.id
        end
    end
    until_date = mattata.string_to_time(until_date, true)
    if until_date == false then
        return mattata.send_reply(message, 'You must specify a length when using this command! This should be in the format 1y2mo3w4d5h6m7s. Some natural language is supported too. temp-mute must be a minimum of 60 seconds in length.')
    elseif not user then
        return mattata.send_reply(message, 'You must specify a user to temp-mute. This can be done by mention, reply or ID.')
    end
    until_date = os.time() + until_date
    local user_object = mattata.get_user(user) -- resolve the username/ID to a user object
    if not user_object then
        return mattata.send_reply(message, language.errors.unknown)
    elseif user_object.result.id == self.info.id then
        return false -- don't let the bot temp-mute itself
    end
    user_object = user_object.result
    local status = mattata.get_chat_member(message.chat.id, user_object.id)
    local is_admin = mattata.is_group_admin(message.chat.id, user_object.id)
    if not status then
        return mattata.send_reply(message, language.errors.generic)
    elseif is_admin then -- we won't try and tempmute moderators and administrators.
        return mattata.send_reply(message, 'I can\'t temp-mute that user as they\'re an admin in this group!')
    elseif status.result.status == 'kicked' then -- check if the user has already been kicked
        return mattata.send_reply(message, 'I can\'t temp-mute that user as they\'re already been banned from this chat!')
    end
    local bot_status = mattata.get_chat_member(message.chat.id, self.info.id)
    if not bot_status then
        return false
    elseif not bot_status.result.can_restrict_members then
        return mattata.send_reply(message, 'It appears I don\'t have the required permissions required in order to temp-mute that user. Please amend this and try again!')
    end
    local success = mattata.restrict_chat_member(message.chat.id, user_object.id, until_date, false, false, false, false, false, false, false, false) -- attempt to temp-mute the user in the group
    if not success then
        return mattata.send_reply(message, 'I couldn\'t temp-mute that user! Please ensure I have the required permissions and try again!')
    end
    mattata.increase_administrative_action(message.chat.id, user_object.id, 'tempmutes')
    local until_formatted = os.date('%c', until_date):gsub('  ', ' ') .. ' GMT +0'
    local admin_username = mattata.get_formatted_user(message.from.id, message.from.first_name, 'html')
    local tempmuted_username = mattata.get_formatted_user(user_object.id, user_object.first_name, 'html')
    if mattata.get_setting(message.chat.id, 'log administrative actions') then
        local log_chat = mattata.get_log_chat(message.chat.id)
        local output = '%s <code>[%s]</code> has temp-muted %s <code>[%s]</code> from %s <code>[%s]</code> until %s.\n%s %s'
        output = string.format(output, admin_username, message.from.id, tempmuted_username, user_object.id, mattata.escape_html(message.chat.title), message.chat.id, until_formatted, '#chat' .. tostring(message.chat.id):gsub('^-100', ''), '#user' .. user_object.id)
        mattata.send_message(log_chat, output, 'html')
    else
        local output = '%s has temp-muted %s until %s.'
        output = string.format(output, admin_username, tempmuted_username, until_formatted)
        mattata.send_message(message.chat.id, output, 'html')
    end
    if message.reply and mattata.get_setting(message.chat.id, 'delete reply on action') then
        mattata.delete_message(message.chat.id, message.reply.message_id)
    end
    return
end

return tempmute