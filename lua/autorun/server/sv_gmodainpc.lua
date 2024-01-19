util.AddNetworkString( "SendAPIKey" )
util.AddNetworkString( "SendPersonality" )

local apiKey
local personality

net.Receive( "SendAPIKey", function( len, ply )
    print( "API key received: ".. net.ReadString() )
    apiKey = net.ReadString()
    _G.apiKey = apiKey -- Set the API key in the Global table
end )

net.Receive( "SendPersonality", function( len, ply )
    print( "Personality received: ".. net.ReadString() )
    personality = net.ReadString()
    _G.personality = "You are apart of a Gmod mod, it is your job to act like this given personality: "..personality .."if you understand, respong with a hello in character" -- Set the personality in the Global table
end )

local meta = FindMetaTable("Player")

meta.sendGPTRequest = function(this, text)
    HTTP({
        url = 'https://api.openai.com/v1/chat/completions',
        type = 'application/json',
        method = 'post',
        headers = {
            ['Content-Type'] = 'application/json',
            ['Authorization'] = 'Bearer '.._G.apiKey, -- Access the API key from the Global table
        },
        body = [[{
            "model": "gpt-3.5-turbo",
            "messages": [{"role": "user", "content": "]]..text..[["}],
            "max_tokens": 50,
            "temperature": 0.7
        }]],
        success = function(code, body, headers)
            local response = util.JSONToTable(body)
            
            if response and response.choices and response.choices[1] and response.choices[1].message and response.choices[1].message.content then
                local gptResponse = response.choices[1].message.content
                this:ChatPrint("[GPT]: "..gptResponse)
            else
                this:ChatPrint((response and response.error and response.error.message) and "Error! "..response.error.message or 'Unknown error!')
            end
        end,
        failed = function(err)
            ErrorNoHalt('HTTP Error: '..err)
        end
    })
end

hook.Add("PlayerSay", "PlayerChatHandler", function(ply, text, team)
    local cmd = string.sub(text,1,4)
    local txt = string.sub(text,5)
    if cmd == "/say" then
        ply:ChatPrint("One moment, please...")
        ply:sendGPTRequest(txt)
        return ""
    elseif cmd == "/api" then // Added a missing comma here
        ply:ChatPrint("api key is: ".._G.apiKey) -- Access the API key from the Global table
        
    end
end)