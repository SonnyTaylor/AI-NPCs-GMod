-- Please dont steal our API key, we are poor
local FREEFREEAPIKEY = "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"

-- Context menu button
local inputapikey = ""
list.Set("DesktopWindows", "ai_menu", {
    title = "AI NPCs",
    icon = "materials/gptlogo/ChatGPT_logo.svg.png",
    init = function(icon, window) drawaihud() end
})

function drawaihud()
    local frame = vgui.Create("DFrame") -- Create a frame for the character selection panel
    frame:SetSize(400, 310) -- Set the size of the frame
    frame:SetTitle("Character Selection") -- Set the title of the frame
    frame:Center() -- Center the frame on the screen
    frame:MakePopup() -- Make the frame a popup
    frame:SetDraggable(true) -- Make the frame draggable
    frame:SetBackgroundBlur(true) -- Enable background blur 
    frame:SetScreenLock(true) -- Lock the mouse to the frame
    frame:SetIcon("materials/gptlogo/ChatGPT_logo.svg.png") -- Set the icon of the frame

    local modelPanel = vgui.Create("DModelPanel", frame) -- Create a model panel for displaying the character model
    modelPanel:Dock(LEFT) -- Dock the model panel to the left side of the frame
    modelPanel:SetSize(200, 0) -- Set the size of the model panel
    modelPanel:SetModel("models/humans/group01/male_07.mdl") -- Set the model for the panel
    modelPanel:SetFOV(48) -- Set the field of view to make the model appear bigger

    -- Increase the rotation speed of the model
    modelPanel.LayoutEntity = function(self, ent)
        self:RunAnimation()
        ent:SetAngles(Angle(0, RealTime() * 100, 0)) -- Increase the rotation speed by modifying the second parameter
    end

    local rightPanel = vgui.Create("DPanel", frame) -- Create a panel for the right side controls
    rightPanel:Dock(FILL) -- Fill the remaining space
    rightPanel:SetBackgroundColor(Color(116, 170, 156)) -- Set a light background color

    local nameLabel = vgui.Create("DLabel", rightPanel) -- Create a label for the AI personality
    nameLabel:SetText("AI Personality:") -- Set the text of the label
    nameLabel:SetPos(10, 10) -- Set the position of the label
    nameLabel:SetSize(170, 20) -- Set the size of the label

    local aiLinkEntry = vgui.Create("DTextEntry", rightPanel) -- Create a text entry for the AI personality
    aiLinkEntry:SetPos(10, 30) -- Set the position of the text entry
    aiLinkEntry:SetSize(170, 20) -- Set the size of the text entry

    local npcLabel = vgui.Create("DLabel", rightPanel) -- Create a label for NPC selection
    npcLabel:SetText("Select NPC:") -- Set the text of the label
    npcLabel:SetPos(10, 60) -- Set the position of the label

    local npcDropdown = vgui.Create("DComboBox", rightPanel) -- Create a dropdown menu for NPC selection
    npcDropdown:SetPos(10, 80) -- Set the position of the dropdown menu
    npcDropdown:SetSize(170, 20) -- Set the size of the dropdown menu
    npcDropdown:SetValue("npc_citizen") -- Set the default value to "npc_citizen"

    -- Get the list of all NPCs and populate the dropdown menu
    local npcTable = list.Get("NPC")
    for npcClass, _ in pairs(npcTable) do npcDropdown:AddChoice(npcClass) end

    local apiKeyLabel = vgui.Create("DLabel", rightPanel) -- Create a label for the API key
    apiKeyLabel:SetText("API Key:") -- Set the text of the label
    apiKeyLabel:SetPos(10, 110) -- Set the position of the label

    local apiKeyEntry = vgui.Create("DTextEntry", rightPanel) -- Create a text entry for the API key
    apiKeyEntry:SetPos(10, 130) -- Set the position of the text entry
    apiKeyEntry:SetSize(170, 20) -- Set the size of the text entry
    apiKeyEntry:SetText(inputapikey) -- Set the default text of the text entry
    local freeAPIButton = vgui.Create("DCheckBoxLabel", rightPanel) -- Create a checkbox for enabling "Free API"
    freeAPIButton:SetText("Free API") -- Set the text of the checkbox
    freeAPIButton:SetPos(10, 155) -- Set the position of the checkbox
    freeAPIButton:SetSize(170, 20) -- Set the size of the checkbox

    freeAPIButton.OnChange = function(self, value)
        if value then
            apiKeyEntry:SetText("") -- Blank out the API key field
            apiKeyEntry:SetEditable(false) -- Disable editing of the API key field
        else
            apiKeyEntry:SetEditable(true) -- Enable editing of the API key field
        end
    end

    local TTSButton = vgui.Create("DCheckBoxLabel", rightPanel) -- Create a button for creating the NPC
    TTSButton:SetText("Text to Speech") -- Set the text of the button
    TTSButton:SetPos(10, 169) -- Nice, Set the position of the button
    TTSButton:SetSize(170, 50) -- Set the size of the button
    TTSButton:SetValue(0)

    local createButton = vgui.Create("DButton", rightPanel) -- Create a button for creating the NPC
    createButton:SetText("Create NPC") -- Set the text of the button
    createButton:SetPos(10, 210) -- Set the position of the button
    createButton:SetSize(170, 60) -- Set the size of the button

    createButton.DoClick = function()
        inputapikey = apiKeyEntry:GetValue()
        -- Send API key
        if freeAPIButton:GetChecked() then
            net.Start("SendAPIKey")
            net.WriteString(FREEAPIKEY)
            net.SendToServer()
        else
            net.Start("SendAPIKey")
            net.WriteString(apiKeyEntry:GetValue())
            net.SendToServer()
        end -- Add this line to close the if block

        -- Send AI personality
        net.Start("SendPersonality")
        net.WriteString(aiLinkEntry:GetValue())
        net.SendToServer()

        -- Send selected NPC class
        net.Start("SendSelectedNPC")
        net.WriteString(npcDropdown:GetValue())
        net.SendToServer()

        -- Send if TTS should be enabled
        net.Start("SendTTS")
        net.WriteBool(TTSButton:GetChecked())
        net.SendToServer()
    end

end

net.Receive("SayTTS", function()
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
                ply.sound = sound -- Store the sound reference in the player entity
            end
        end)
end)

-- Update the position of the TTS sound for all players
hook.Add("Think", "FollowPlayerSound", function()
    for k, v in pairs(player.GetAll()) do
        if IsValid(v.sound) then
            v.sound:SetPos(v:GetPos()) -- Set the sound position to the player's position
        end
    end
end)
