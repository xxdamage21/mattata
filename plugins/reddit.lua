--[[
    Based on a plugin by topkecleon.
    Copyright 2020 Matthew Hesketh <matthew@matthewhesketh.com>
    This code is licensed under the MIT. See LICENSE for details.
]]

local reddit = {}
local mattata = require('mattata')
local https = require('ssl.https')
local url = require('socket.url')
local json = require('dkjson')

function reddit:init()
    reddit.commands = mattata.commands(self.info.username, { '^/r/' }):command('r/'):command('reddit').table
    reddit.help = '/r/subreddit - Returns the latest posts from the given subreddit.'
end

function reddit.format_results(posts)
    local output = {}
    if #posts == 0 then
        return false
    end
    for k, v in pairs(posts) do
        local post = v.data
        local title = post.title
        if title:len() > 250 then
            title = mattata.trim(title:sub(1, 250)) .. '...'
        end
        local short_url = 'redd.it/' .. post.id
        local result = '<a href="' .. mattata.escape_html(short_url) .. '">' .. mattata.escape_html(title) .. '</a>'
        if post.domain and not post.is_self then
            post.url = mattata.escape_html(post.url)
            post.domain = mattata.escape_html(post.domain)
            result = mattata.symbols.bullet .. ' <code>[</code><a href="' .. post.url .. '">' .. post.domain .. '</a><code>]</code> ' .. result
            table.insert(output, result)
        end
    end
    return table.concat(output, '\n')
end

function reddit:on_message(message, configuration, language)
    local limit = message.chat.type ~= 'private' and 4 or 8
    local input = mattata.input(message.text)
    local subreddit = message.text:match('^/r/([%w][%w_]+)%s?')
    if input and not subreddit then
        subreddit = input
    elseif not input and not subreddit then
        return mattata.send_reply(message, reddit.help)
    end
    if not subreddit or subreddit:len() > 21 or subreddit:len() < 2 then
        return mattata.send_reply(message, 'That\'s not a valid subreddit!')
    end
    local output = '<b>/r/' .. subreddit .. '</b>\n'
    local request_url = 'https://www.reddit.com/.json?limit=' .. limit
    if subreddit ~= 'all' then
        request_url = 'https://www.reddit.com/r/' .. subreddit .. '/.json?limit=' .. limit
    end
    local old_timeout = https.TIMEOUT
    https.TIMEOUT = 1
    local jstr, res = https.request(request_url)
    https.TIMEOUT = old_timeout
    if res == 404 or res == 'wantread' then
        return mattata.send_reply(message, language['errors']['results'])
    elseif res ~= 200 then
        return mattata.send_reply(message, language['errors']['connection'])
    end
    local jdat = json.decode(jstr)
    if not jdat or not jdat.data or #jdat.data.children < 1 then
        return mattata.send_reply(message, language['errors']['results'])
    end
    output = output .. reddit.format_results(jdat.data.children)
    return mattata.send_message(message.chat.id, output, 'html', true)
end

return reddit