--[[
    Copyright 2020 Matthew Hesketh <matthew@matthewhesketh.com>
    This code is licensed under the MIT. See LICENSE for details.
]]

local ai = {}
local mattata = require('mattata')
local https = require('ssl.https')
local url = require('socket.url')
local ltn12 = require('ltn12')
local md5 = require('md5')


function ai:on_new_message(message)
    if not message.text or message.is_command then
        return false
    elseif message.text and message.reply and message.reply.text and message.reply.from.id == self.info.id and not message.reply.entities then
        return ai.on_message(self, message)
    end
    local triggers = {
        '^' .. self.info.first_name:lower() .. ',? ',
        '^@?' .. self.info.username:lower() .. ',? '
    }
    for _, trigger in pairs(triggers) do
        if message.text:lower():match(trigger) then
            return ai.on_message(self, message)
        end
    end
    if message.chat.type == 'private' and not message.is_command and not message.text:match('^[/!#]') and message.text then
        return ai.on_message(self, message)
    end
    return
end

function ai.unescape(str)
    if not str then
        return false
    end
    str = str:gsub('%%(%x%x)', function(x)
        return tostring(tonumber(x, 16)):char()
    end)
    return str
end

function ai.cookie()
    local cookie = {}
    local _, res, headers = https.request({
        ['url'] = 'http://www.cleverbot.com/',
        ['method'] = 'GET'
    })
    if res ~= 200 then
        return false
    end
    local set = headers['set-cookie']
    local k, v = set:match('([^%s;=]+)=?([^%s;]*)')
    cookie[k] = v
    return cookie
end

function ai.talk(message, reply)
    if not message then
        return false
    end
    return ai.cleverbot(message, reply)
end

function ai.cleverbot(message, reply)
    local cookie = ai.cookie()
    if not cookie then
        return false
    end
    for k, v in pairs(cookie) do
        cookie[#cookie + 1] = k .. '=' .. v
    end
    local query = 'stimulus=' .. url.escape(message)
    if reply then
        query = query .. '&vText2=' .. url.escape(reply)
    end
    query = query .. '&cb_settings_scripting=no&islearning=1&icognoid=wsf&icognocheck='
    local icognocheck = md5.sumhexa(query:sub(8, 33))
    query = query .. icognocheck
    local agents = {
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36',
        'Mozilla/5.0 CK={} (Windows NT 6.1; WOW64; Trident/7.0; rv:11.0) like Gecko',
        'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.140 Safari/537.36 Edge/18.17763'
    }
    local agent = agents[math.random(#agents)]
    local old = https.TIMEOUT
    https.TIMEOUT = 2
    local _, res, headers = https.request({
        ['url'] = 'https://www.cleverbot.com/webservicemin?uc=UseOfficialCleverbotAPI&dl=en&flag=&user=&mode=1&alt=0&reac=&emo=&sou=website&xed=&',
        ['method'] = 'POST',
        ['headers'] = {
            ['Host'] = 'www.cleverbot.com',
            ['User-Agent'] = agent,
            ['Accept'] = '*/*',
            ['Accept-Language'] = 'en-US,en;q=0.5',
            ['Accept-Encoding'] = 'gzip, deflate',
            ['Referrer'] = 'https://www.cleverbot.com/',
            ['Content-Length'] = query:len(),
            ['Content-Type'] = 'text/plain;charset=UTF-8',
            ['Cookie'] = table.concat(cookie, ';'),
            ['DNT'] = '1'
        },
        ['source'] = ltn12.source.string(query)
    })
    https.TIMEOUT = old
    if res ~= 200 or not headers.cboutput then
        return false
    end
    local output = ai.unescape(headers.cboutput)
    if not output then
        return false
    end
    return output
end

function ai:process(message, reply)
    if not message then
        return ai.unsure()
    end
    local original_message = message
    message = message:lower()
    if message:match('^hi%s*') or message:match('^hello%s*') or message:match('^howdy%s*') or message:match('^hi.?$') or message:match('^hello.?$') or message:match('^howdy.?$') then
        return ai.greeting()
    elseif message:match('^bye%s*') or message:match('^good[%-%s]?bye%s*') or message:match('^bye$') or message:match('^good[%-%s]?bye$') then
        return ai.farewell()
    elseif message:match('%s*y?o?ur%s*name%s*') or message:match('^what%s*is%s*y?o?ur%s*name') then
        return string.format('My name is %s, what\'s yours?', self.info.first_name)
    elseif message:match('^do y?o?u[%s.]*') then
        return ai.choice(message)
    elseif message:match('^how%s*a?re?%s*y?o?u.?') or message:match('.?how%s*a?re?%s*y?o?u%s*') or message:match('.?how%s*a?re?%s*y?o?u.?$') or message:match('^a?re?%s*y?o?u%s*oka?y?.?$') or message:match('%s*a?re?%s*y?o?u%s*oka?y?.?$') then
        return ai.feeling()
    else
        return ai.talk(original_message, reply or false)
    end
end

function ai.greeting()
    local greetings = {
        'Hello!',
        'Hi.',
        'How are you?',
        'What\'s up?',
        'Are you okay?',
        'How\'s it going?',
        'What\'s your name?',
        'What are you up to?',
        'Hello.',
        'Hey!',
        'Hey.',
        'Howdy!',
        'Howdy.',
        'Hello there!',
        'Hello there.'
    }
    return greetings[math.random(#greetings)]
end

function ai.farewell()
    local farewells = {
        'Goodbye!',
        'Bye.',
        'I\'ll speak to you later, yeah?',
        'See ya!',
        'Oh, bye then.',
        'Bye bye.',
        'BUH-BYE!',
        'Aw. See ya.'
    }
    return farewells[math.random(#farewells)]
end

function ai.unsure()
    local unsure = {
        'What?',
        'I really don\'t understand.',
        'What are you trying to say?',
        'Huh?',
        'Um..?',
        'Excuse me?',
        'What does that mean?'
    }
    return unsure[math.random(#unsure)]
end

function ai.feeling()
    local feelings = {
        'I am good thank you!',
        'I am well.',
        'Good, how about you?',
        'Very well thank you; you?',
        'Never better!',
        'I feel great!'
    }
    return feelings[math.random(#feelings)]
end

function ai.choice(message)
    local generic_choices = {
        'I do!',
        'I do not.',
        'Nah, of course not!',
        'Why would I?',
        'Um...',
        'I sure do!',
        'Yes, do you?',
        'Nope!',
        'Yeah!'
    }
    local personal_choices = {
        'I love you!',
        'I\'m sorry, but I don\'t really like you!',
        'I really like you.',
        'I\'m crazy about you!'
    }
    if message:match('%s*me.?$') then
        return personal_choices[math.random(#personal_choices)]
    end
    return generic_choices[math.random(#generic_choices)]
end

function ai.offline()
    local responses = {
        'I don\'t feel like talking right now!',
        'I don\'t want to talk at the moment.',
        'Can we talk later?',
        'I\'m not in the mood right now...',
        'Leave me alone!',
        'Please can I have some time to myself?',
        'I really don\'t want to talk to anyone right now!',
        'Please leave me in peace.',
        'I don\'t wanna talk right now, I hope you understand.'
    }
    return responses[math.random(#responses)]
end

function ai:on_message(message)
    self.is_ai = true
    mattata.send_chat_action(message.chat.id, 'typing')
    local text = message.text:gsub('^' .. self.info.first_name:lower() .. ',? ', ''):gsub('^@?' .. self.info.username:lower() .. ',? ', '')
    text = text:gsub(self.info.first_name:lower(), 'you'):gsub('@?' .. self.info.username:lower(), 'you')
    local reply = false
    if message.reply and message.reply.text and message.reply.from.id == self.info.id and not message.reply.entities then
        reply = message.reply.text
    end
    local output = ai.process(self, text, reply)
    if not output then
        return false
    end
    local success = mattata.send_reply(message, output)
    if output:lower():match('g?o?o?d?bye') or output:lower():match('see ya') and not mattata.is_group_admin(message.chat.id, self.info.id) and mattata.is_group_admin(message.chat.id, message.from.id) then
        return mattata.leave_chat(message.chat.id)
    end
    return success
end

return ai