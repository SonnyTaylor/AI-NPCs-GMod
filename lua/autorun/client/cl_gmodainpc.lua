providers = include('providers/providers.lua')

-- Context menu button
local inputapikey = ""
list.Set("DesktopWindows", "ai_menu", {
    title = "AI NPCs",
    icon = "materials/gptlogo/ChatGPT_logo.svg.png",
    init = function(icon, window) drawaihud() end
})

local modelPanel
function drawaihud()
    local frame = vgui.Create("DFrame") -- Create a frame for the character selection panel
    frame:SetSize(400, 480) -- Set the size of the frame
    frame:SetTitle("Character Selection") -- Set the title of the frame
    frame:Center() -- Center the frame on the screen
    frame:MakePopup() -- Make the frame a popup
    frame:SetDraggable(true) -- Make the frame draggable
    frame:SetBackgroundBlur(true) -- Enable background blur 
    frame:SetScreenLock(true) -- Lock the mouse to the frame
    frame:SetIcon("materials/gptlogo/ChatGPT_logo.svg.png") -- Set the icon of the frame

    -- Left: 3D model display
    modelPanel = vgui.Create("DModelPanel", frame)
    modelPanel:Dock(LEFT)
    modelPanel:SetSize(200, 0)
    modelPanel:SetModel("models/humans/group01/male_07.mdl")
    modelPanel:SetFOV(48)
    modelPanel.LayoutEntity = function(self, ent)
        self:RunAnimation()
        ent:SetAngles(Angle(0, RealTime() * 100, 0))
    end

    -- Right: Controls
    local rightPanel = vgui.Create("DPanel", frame)
    rightPanel:Dock(FILL)
    rightPanel:SetBackgroundColor(Color(116, 170, 156))

    -- AI Personality
    local nameLabel = vgui.Create("DLabel", rightPanel)
    nameLabel:SetText("AI Personality:")
    nameLabel:SetPos(10, 10)
    nameLabel:SetSize(170, 20)
    local aiLinkEntry = vgui.Create("DTextEntry", rightPanel)
    aiLinkEntry:SetPos(10, 30)
    aiLinkEntry:SetSize(170, 20)

    -- Provider selection
    local providerLabel = vgui.Create("DLabel", rightPanel)
    providerLabel:SetText("Provider:")
    providerLabel:SetPos(10, 60)
    local providerDropdown = vgui.Create("DComboBox", rightPanel)
    providerDropdown:SetPos(10, 80)
    providerDropdown:SetSize(170, 20)
    providerDropdown:AddChoice("OpenAI", "openai", true)
    providerDropdown:AddChoice("OpenRouter", "openrouter")
    providerDropdown:AddChoice("Groq", "groq")
    providerDropdown:AddChoice("Ollama", "ollama")

    -- Hostname entry
    local hostnameLabel = vgui.Create("DLabel", rightPanel)
    hostnameLabel:SetText("Hostname:")
    hostnameLabel:SetPos(10, 110)
    local hostnameEntry = vgui.Create("DTextEntry", rightPanel)
    hostnameEntry:SetPos(10, 130)
    hostnameEntry:SetSize(170, 20)

    -- Model selection or input
    local modelLabel = vgui.Create("DLabel", rightPanel)
    modelLabel:SetText("Model:")
    modelLabel:SetPos(10, 160)
    local modelDropdown = vgui.Create("DComboBox", rightPanel)
    modelDropdown:SetPos(10, 180)
    modelDropdown:SetSize(170, 20)
    local modelTextEntry = vgui.Create("DTextEntry", rightPanel)
    modelTextEntry:SetPos(10, 180)
    modelTextEntry:SetSize(170, 20)
    modelTextEntry:SetVisible(false)

    -- Populate initial model list
    local initialModels = providers.get("openai").models or {}
    if #initialModels > 0 then
        for _, m in ipairs(initialModels) do modelDropdown:AddChoice(m) end
        modelDropdown:ChooseOptionID(1)
    else
        modelDropdown:SetVisible(false)
        modelTextEntry:SetVisible(true)
    end

    -- Provider change handler
    function providerDropdown:OnSelect(self, idx, data)
        if data == "ollama" then
            hostnameEntry:SetEditable(true)
        else
            hostnameEntry:SetEditable(false)
        end

        local models = providers.get(data).models or {}
        modelDropdown:Clear()
        if #models > 0 then
            modelDropdown:SetVisible(true)
            modelTextEntry:SetVisible(false)
            for _, m in ipairs(models) do modelDropdown:AddChoice(m) end
            modelDropdown:ChooseOptionID(1)
        else
            modelDropdown:SetVisible(false)
            modelTextEntry:SetVisible(true)
        end
    end

    -- NPC selection
    local npcLabel = vgui.Create("DLabel", rightPanel)
    npcLabel:SetText("Select NPC:")
    npcLabel:SetPos(10, 210)
    local npcDropdown = vgui.Create("DComboBox", rightPanel)
    npcDropdown:SetPos(10, 230)
    npcDropdown:SetSize(170, 20)
    npcDropdown:SetValue("npc_citizen")
    function npcDropdown:OnSelect(self, idx, data)
        net.Start("GetNPCModel")
        net.WriteTable(data)
        net.SendToServer()
    end
    for npcId, npcData in pairs(ents._SpawnMenuNPCs) do
        npcData.Id = npcId
        npcDropdown:AddChoice(npcId, npcData)
    end
    npcDropdown:ChooseOptionID(1)

    -- API key
    local apiKeyLabel = vgui.Create("DLabel", rightPanel)
    apiKeyLabel:SetText("API Key:")
    apiKeyLabel:SetPos(10, 260)
    local apiKeyEntry = vgui.Create("DTextEntry", rightPanel)
    apiKeyEntry:SetPos(10, 280)
    apiKeyEntry:SetSize(170, 20)
    apiKeyEntry:SetText(inputapikey)

    -- Free API toggle
    local freeAPIButton = vgui.Create("DCheckBoxLabel", rightPanel)
    freeAPIButton:SetText("Free API")
    freeAPIButton:SetPos(10, 310)
    freeAPIButton:SetSize(170, 20)
    freeAPIButton.OnChange = function(self, value)
        apiKeyEntry:SetText(value and "" or apiKeyEntry:GetText())
        apiKeyEntry:SetEditable(not value)
    end

    -- Text-to-speech toggle
    local TTSButton = vgui.Create("DCheckBoxLabel", rightPanel)
    TTSButton:SetText("Text to Speech")
    TTSButton:SetPos(10, 330)
    TTSButton:SetSize(170, 20)
    TTSButton:SetValue(0)

    -- Create NPC button
    local createButton = vgui.Create("DButton", rightPanel)
    createButton:SetText("Create NPC")
    createButton:SetPos(10, 360)
    createButton:SetSize(170, 60)
    createButton.DoClick = function()
        inputapikey = apiKeyEntry:GetValue()
        APIKEY = freeAPIButton:GetChecked() and "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" or apiKeyEntry:GetValue()

        local _, selectedNPC = npcDropdown:GetSelected()
        local _, provider = providerDropdown:GetSelected()
        -- Choose model or input
        local chosenModel = modelDropdown:IsVisible() and modelDropdown:GetValue() or modelTextEntry:GetValue()

        local requestBody = {
            apiKey = APIKEY,
            hostname = hostnameEntry:GetValue(),
            personality = aiLinkEntry:GetValue(),
            NPCData = selectedNPC,
            enableTTS = TTSButton:GetChecked(),
            provider = provider,
            model = chosenModel,
        }

        PrintTable(requestBody)
        net.Start("SendNPCInfo")
        net.WriteTable(requestBody)
        net.SendToServer()
    end
end

soundList = {}

net.Receive("RespondNPCModel", function()
    local modelPath = net.ReadString()

    modelPanel:SetModel(modelPath)
end)

-- TODO Convert this to serverside code so that audio can changed to follow NPC
net.Receive("SayTTS", function()
    local key = net.ReadString()
    local text = net.ReadString() -- Read the TTS text from the network
    local ply = net.ReadEntity() -- Read the player entity from the network
    text = string.sub(string.Replace(text, " ", "%20"), 1, 1000) -- Replace spaces with "%20" and limit the text length to 100 characters

    -- Play the TTS sound using the provided URL
    sound.PlayURL(
        "https://tetyys.com/SAPI4/SAPI4?voice=Sam&pitch=100&speed=150&text=" ..
            text, "3d", function(sound)
            if IsValid(sound) then
                sound:SetPos(ply:GetPos()) -- Set the sound position to the player's position
                sound:SetVolume(1) -- Set the sound volume to maximum
                sound:Play() -- Play the sound
                sound:Set3DFadeDistance(200, 1000) -- Set the 3D sound fade distance
                soundList[key] = sound -- Store the sound reference in the player entity
            end
        end)
end)

net.Receive("TTSPositionUpdate", function()
    local key = net.ReadString()
    local pos = net.ReadVector()

    soundList[key]:SetPos(pos)
end)