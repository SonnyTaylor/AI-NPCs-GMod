-- Add network strings for communication between client and server
util.AddNetworkString("GetNPCModel")
util.AddNetworkString("RespondNPCModel")
util.AddNetworkString("SendNPCInfo")
util.AddNetworkString("SayTTS")
util.AddNetworkString("TTSPositionUpdate")

providers = include('providers/providers.lua')

local spawnedNPC = {} -- Variable to store the reference to the spawned NPC

net.Receive("GetNPCModel", function(len, ply)
    local NPCData = net.ReadTable()
    local model

    if !NPCData.Model then
        local entity = ents.Create(NPCData.Class)
        entity:Spawn()
        
        -- Hide NPC everywhere except inside model panel
        entity:SetSaveValue("m_takedamage", 0)
        entity:SetMoveType(MOVETYPE_NONE)
        entity:SetSolid(SOLID_NONE)
        entity:SetRenderMode(RENDERMODE_TRANSALPHA)
        entity:SetColor(Color(255, 255, 255, 0))

        if !IsValid(entity) then return end

        model = entity:GetModel()
        
        entity:Remove()
    else
        model = NPCData.Model
    end

    net.Start("RespondNPCModel")
    net.WriteString(model)
    net.Send(ply)

end)

net.Receive("SendNPCInfo", function(len, ply)
    local data = net.ReadTable()
    print("Data received:")
    print(data)

    local apiKey = data["apiKey"]
    -- Please dont steal our API key, we are poor
    -- TODO Add Encrpytion Decrpytion crap to obfuscate api key
    if apiKey == "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" then
        print("Free API key received")
    else
        print("API key received: " .. apiKey)
    end

    if apiKey == "" then
        ply:ChatPrint("Invalid API key.")
        return nil
    end
    -- Generate a unique key for the NPC
    local key = table.insert(spawnedNPC, {})

    spawnedNPC[key]["history"] = {}

    spawnedNPC[key]["provider"] = data["provider"]
    spawnedNPC[key]["hostname"] = data["hostname"]
    spawnedNPC[key]["apiKey"] = apiKey
    spawnedNPC[key]["max_tokens"] = 50
    spawnedNPC[key]["temperature"] = 0.7
    spawnedNPC[key]["enableTTS"] = data["enableTTS"]

    local personality = data["personality"]
    print("Personality received: " .. personality)
    spawnedNPC[key]["personality"] = "it is your job to act like this personality: " ..
                                     personality ..
                                     "if you understand, respond with a hello in character" -- Set the personality in the Global table

    -- Calculate spawn position in front of the player
    local spawnPosition = ply:GetEyeTrace().HitPos

    -- Generate a random angle for the NPC
    local spawnAngle = Angle(0, math.random(0, 360), 0)

    -- Spawn the selected NPC with the random angle
    spawnedNPC[key]["npc"] = SpawnNPC(spawnPosition, spawnAngle, data["NPCData"], key)

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

    ply:sendGPTRequest(key, 'system', spawnedNPC[key]["personality"])
end)

-- Define SpawnNPC function
function SpawnNPC(pos, ang, npcData, key)
    local npc = ents.Create(npcData.Class)
    if not IsValid(npc) then return end

    npc:SetPos(pos)
    npc:SetAngles(ang)
    npc:Spawn()
    if npcData.Model then npc:SetModel(npcData.Model) end

    -- Set up a hook for the NPC's death event
    hook.Add("OnNPCKilled", "OnAIDeath", function(npc, attacker, inflictor)
        if npc == spawnedNPC[key]["npc"] then
            print("AI NPC died or was despawned.")
            spawnedNPC[key] = nil -- Remove NPC from list
            hook.Remove("OnNPCKilled", "OnAIDeath") -- Remove the hook after processing
        end
    end)

    -- Set up a hook for the NPC's despawn event
    hook.Add("EntityRemoved", "OnAIDespawn", function(entity)
        if entity == spawnedNPC[key]["npc"] then
            print("AI NPC was despawned.")
            spawnedNPC[key] = nil -- Remove NPC from list
            hook.Remove("EntityRemoved", "OnAIDespawn") -- Remove the hook after processing
        end
    end)
    return npc
end

-- Find the metatable for the Player type
local meta = FindMetaTable("Player")

-- Extend the Player metatable to add a custom function for sending requests to GPT-3
meta.sendGPTRequest = function(this, key, author, text)
    table.insert(spawnedNPC[key]["history"], {
        role = author,
        content = text
    })

    local provider = providers.get(spawnedNPC[key]["provider"])

    provider.request(spawnedNPC[key], function(err, response)
        if err then
            ErrorNoHalt("Error: " .. err)
        else
            -- Check if the response contains valid data
            if response and response.choices and response.choices[1] and
            response.choices[1].message and
            response.choices[1].message.content then
                -- Extract the GPT-3 response content
                local gptResponse = response.choices[1].message.content

                table.insert(spawnedNPC[key]["history"], {
                    role = "assistant",
                    content = gptResponse
                })

                -- Print the GPT-3 response to the player's voice chat through tts
                if spawnedNPC[key]["enableTTS"] then
                    net.Start("SayTTS")
                    net.WriteString(key)
                    net.WriteString(gptResponse)
                    net.WriteEntity(spawnedNPC[key]["npc"])
                    net.Broadcast()
                else
                    local text = "[AI]: " .. gptResponse

                    local chunks = {}
                    local chunkSize = 200

                    for i = 1, #text, chunkSize do
                        local startIndex = i
                        local endIndex = math.min(i + chunkSize - 1, #text) 
                        table.insert(chunks, text:sub(startIndex, endIndex))
                    end

                    for _, chunk in ipairs(chunks) do
                    this:ChatPrint(chunk)
                    end
                end
            else
                -- Print an error message if the response is invalid or contains an error
                this:ChatPrint((response and response.error and
                                response.error.message) and "Error! " ..
                                response.error.message or
                                "Unknown error! api key is: " .. spawnedNPC[key]["apiKey"] ..
                                '')
            end
        end
    end)
end

hook.Add("PlayerSay", "PlayerChatHandler", function(ply, text, team)
    local cmd = string.sub(text, 1, 4)
    local txt = string.sub(text, 5)
    if cmd == "/say" then
        ply:ChatPrint("One moment, please...")
        for key, _ in pairs(spawnedNPC) do
            ply:sendGPTRequest(key, 'user', txt) -- Send the player's message to GPT-3
        end
        return ""
    end
end)

hook.Add("Think", "FollowNPCSound", function()
    for k, v in pairs(spawnedNPC) do
        if v["enableTTS"] then
            net.Start("TTSPositionUpdate")
            net.WriteString(k)
            net.WriteVector(v.npc:GetPos())
            net.Broadcast()
        end
    end
end)

-- Reset isAISpawned flag on cleanup
hook.Add("OnCleanup", "ResetAISpawnedFlag",
         function() spawnedNPC = {} end)
-- Reset isAISpawned flag on admin cleanup
hook.Add("AdminCleanup", "ResetAISpawnedFlagAdmin",
         function() spawnedNPC = {} end)

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
