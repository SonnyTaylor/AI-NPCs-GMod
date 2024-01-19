
-- Add network strings for communication between client and server
util.AddNetworkString( "SendAPIKey" )
util.AddNetworkString( "SendPersonality" )
util.AddNetworkString( "SendSelectedNPC" )

local personality
local selectedNPC

-- Receive API key from client
net.Receive( "SendAPIKey", function( len, ply )
    apiKey = net.ReadString()
    print( "API key received: ".. apiKey )
    _G.apiKey = apiKey -- Set the API key in the Global table
end )

local apikey = _G.apiKey

-- Receive personality from client
net.Receive( "SendPersonality", function( len, ply )
    personality = net.ReadString()
    print( "Personality received: ".. personality )
    _G.personality = "it is your job to act like this personality: "..personality .."if you understand, respond with a hello in character" -- Set the personality in the Global table
end )

-- Define SpawnNPC function
function SpawnNPC(pos, ang, npcClass)
    local npc = ents.Create(npcClass)
    if not IsValid(npc) then return end

    npc:SetPos(pos)
    npc:SetAngles(ang)
    npc:Spawn()

    return npc
end

-- Receive selected NPC from client
net.Receive("SendSelectedNPC", function(len, ply)
    local selectedNPC = net.ReadString()
    print("Selected NPC received: " .. selectedNPC)
    
    -- Calculate spawn position in front of the player
    local spawnPosition = ply:GetEyeTrace().HitPos

    -- Generate a random angle for the NPC
    local spawnAngle = Angle(0, math.random(0, 360), 0)

    -- Spawn the selected NPC with the random angle
    local spawnedNPC = SpawnNPC(spawnPosition, spawnAngle, selectedNPC)
    
    if IsValid(spawnedNPC) then
        print("NPC spawned successfully!")
    else
        print("Failed to spawn NPC.")
    end

    ply:sendGPTRequest(_G.personality)

end)



-- Find the metatable for the Player type
local meta = FindMetaTable("Player")

-- Extend the Player metatable to add a custom function for sending requests to GPT-3
meta.sendGPTRequest = function(this, text)
    -- Use the HTTP library to make a request to the GPT-3 API
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
            -- Parse the JSON response from the GPT-3 API
            local response = util.JSONToTable(body)
            
            -- Check if the response contains valid data
            if response and response.choices and response.choices[1] and response.choices[1].message and response.choices[1].message.content then
                -- Extract the GPT-3 response content
                local gptResponse = response.choices[1].message.content
                
                -- Print the GPT-3 response to the player's chat
                this:ChatPrint("["..personality.."]: "..gptResponse)
            else
                -- Print an error message if the response is invalid or contains an error
                this:ChatPrint((response and response.error and response.error.message) and "Error! "..response.error.message or 'Unknown error! api key is: '.._G.apiKey..'')
            end
        end,
        failed = function(err)
            -- Print an error message if the HTTP request fails
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

-- Hook to listen for chat messages
hook.Add("PlayerSay", "CheckAllNPCs", function(ply, text, teamChat)
    -- Check if the player typed the command "!allnpcs"
    if string.lower(text) == "!allnpcs" then
        -- Get the list of all NPCs
        local npcTable = list.Get("NPC")

        -- Send the list of all NPCs to the chat
        for npcClass, npcData in pairs(npcTable) do
            ply:ChatPrint("NPC Class: " .. npcClass)
            PrintTable(npcData)
            ply:ChatPrint("--------------------------")
        end

        -- Return an empty string to prevent the original message from being sent
        return ""
    end
end)