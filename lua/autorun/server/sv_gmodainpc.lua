-- Add network strings for communication between client and server
util.AddNetworkString("SendAPIKey")
util.AddNetworkString("SendPersonality")
util.AddNetworkString("SendSelectedNPC")
util.AddNetworkString("SayTTS")
util.AddNetworkString("SendTTS")

local personality
local selectedNPC
local isAISpawned = false -- Flag to track whether AI NPC is already spawned
local spawnedNPC -- Variable to store the reference to the spawned NPC
local TTSEnabled = false -- Flag to track whether TTS is enabled

-- Receive API key from client
net.Receive("SendAPIKey", function(len, ply)
    apiKey = net.ReadString()
    -- Please dont steal our API key, we are poor
    -- TODO Add Encrpytion Decrpytion crap to obfuscate api key
    if apiKey == "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" then
        print("Free API key received")
    else
        print("API key received: " .. apiKey)
    end
    _G.apiKey = apiKey -- Set the API key in the Global table

    if apiKey == "" then ply:ChatPrint("Invalid API key.") end
end)

net.Receive("SendTTS", function(len, ply)
    TTSEnabled = net.ReadBool()
    print("TTS enabled: " .. tostring(TTSEnabled))
    _G.TTSEnabled = TTSEnabled -- Set the TTS flag in the Global table
end)

-- Receive personality from client
net.Receive("SendPersonality", function(len, ply)
    personality = net.ReadString()
    print("Personality received: " .. personality)
    _G.personality = "it is your job to act like this personality: " ..
                         personality ..
                         "if you understand, respond with a hello in character" -- Set the personality in the Global table
    _G.personalitynohello =
        "it is your job to act like this personality and talk like them exactly and you must not talk like Chatgpt at all: " ..
            personality
end)

-- Define SpawnNPC function
function SpawnNPC(pos, ang, npcClass)
    local npc = ents.Create(npcClass)
    if not IsValid(npc) then return end

    npc:SetPos(pos)
    npc:SetAngles(ang)
    npc:Spawn()

    -- Set up a hook for the NPC's death event
    hook.Add("OnNPCKilled", "OnAIDeath", function(npc, attacker, inflictor)
        if npc == spawnedNPC then
            isAISpawned = false
            print("AI NPC died or was despawned.")
            hook.Remove("OnNPCKilled", "OnAIDeath") -- Remove the hook after processing
        end
    end)

    -- Set up a hook for the NPC's despawn event
    hook.Add("EntityRemoved", "OnAIDespawn", function(entity)
        if entity == spawnedNPC then
            isAISpawned = false
            print("AI NPC was despawned.")
            hook.Remove("EntityRemoved", "OnAIDespawn") -- Remove the hook after processing
        end
    end)
    return npc
end

-- Receive selected NPC from client
net.Receive("SendSelectedNPC", function(len, ply)
    if isAISpawned then
        ply:ChatPrint("AI NPC is already spawned.")
        return
    end

    local selectedNPC = net.ReadString()
    print("Selected NPC received: " .. selectedNPC)

    -- Calculate spawn position in front of the player
    local spawnPosition = ply:GetEyeTrace().HitPos

    -- Generate a random angle for the NPC
    local spawnAngle = Angle(0, math.random(0, 360), 0)

    -- Spawn the selected NPC with the random angle
    spawnedNPC = SpawnNPC(spawnPosition, spawnAngle, selectedNPC)

    if IsValid(spawnedNPC) then
        print("NPC spawned successfully!")
        isAISpawned = true

        -- Enable navigation for the NPC
        spawnedNPC:SetNPCState(NPC_STATE_SCRIPT)
        spawnedNPC:SetSchedule(SCHED_IDLE_STAND)

        -- Walk to the player
        spawnedNPC:SetLastPosition(ply:GetPos())
        spawnedNPC:SetSchedule(SCHED_FORCED_GO_RUN)
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
    local requestBody = {
        model = "gpt-3.5-turbo",
        messages = {
            {
                role = "user",
                content = text
            }
        },
        max_tokens = 50, 
        temperature = 0.7
    }

    local function correctFloatToInt(jsonString)
        return string.gsub(jsonString, '(%d+)%.0', '%1')
    end

    HTTP({
        url = "https://api.openai.com/v1/chat/completions",
        type = "application/json",
        method = "post",
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. _G.apiKey -- Access the API key from the Global table
        },
        body = correctFloatToInt(util.TableToJSON(requestBody)), -- tableToJSON changes integers to float

        success = function(code, body, headers)
            -- Parse the JSON response from the GPT-3 API
            local response = util.JSONToTable(body)

            -- Check if the response contains valid data
            if response and response.choices and response.choices[1] and
                response.choices[1].message and
                response.choices[1].message.content then
                -- Extract the GPT-3 response content
                local gptResponse = response.choices[1].message.content

                -- Print the GPT-3 response to the player's voice chat through tts
                if _G.TTSEnabled then
                    net.Start("SayTTS")
                    net.WriteString(gptResponse)
                    net.WriteEntity(this)
                    net.Broadcast()
                else
                    this:ChatPrint("[AI]: " .. gptResponse)
                end
            else
                -- Print an error message if the response is invalid or contains an error
                this:ChatPrint((response and response.error and
                                   response.error.message) and "Error! " ..
                                   response.error.message or
                                   "Unknown error! api key is: " .. _G.apiKey ..
                                   '')
            end
        end,
        failed = function(err)
            -- Print an error message if the HTTP request fails
            ErrorNoHalt("HTTP Error: " .. err)
        end
    })
end

hook.Add("PlayerSay", "PlayerChatHandler", function(ply, text, team)
    local cmd = string.sub(text, 1, 4)
    local txt = string.sub(text, 5)
    if cmd == "/say" then
        ply:ChatPrint("One moment, please...")
        ply:sendGPTRequest(_G.personalitynohello .. "RESPONDTOTHIS" .. txt) -- Send the player's message to GPT-3
        return ""
    end
end)

-- Reset isAISpawned flag on cleanup
hook.Add("OnCleanup", "ResetAISpawnedFlag",
         function(name) isAISpawned = false end)
-- Reset isAISpawned flag on admin cleanup
hook.Add("AdminCleanup", "ResetAISpawnedFlagAdmin",
         function() isAISpawned = false end)

-- Function to encode the API key
function encode_key(api_key)
    local encoded_key = ""
    for i = 1, #api_key do
        encoded_key = encoded_key .. string.char(string.byte(api_key, i) + 1)
    end
    return encoded_key
end

-- Function to decode the API key
function decode_key(encoded_key)
    local decoded_key = ""
    for i = 1, #encoded_key do
        decoded_key = decoded_key ..
                          string.char(string.byte(encoded_key, i) - 1)
    end
    return decoded_key
end
