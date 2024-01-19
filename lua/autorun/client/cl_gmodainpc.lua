-- Context menu button
local inputapikey = ""
list.Set( "DesktopWindows", "ai_menu", 
{
    title = "AI NPCs",
    icon = "materials/gptlogo/ChatGPT_logo.svg.png",
    init = function( icon, window )
        drawaihud()
    end
} )

function drawaihud()
    local frame = vgui.Create("DFrame") -- Create a frame for the character selection panel
    frame:SetSize(400, 300) -- Set the size of the frame
    frame:SetTitle("Character Selection") -- Set the title of the frame
    frame:Center() -- Center the frame on the screen
    frame:MakePopup() -- Make the frame a popup

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

    local aiLinkEntry = vgui.Create("DTextEntry", rightPanel) -- Create a text entry for the AI personality
    aiLinkEntry:SetPos(10, 30) -- Set the position of the text entry
    aiLinkEntry:SetSize(150, 20) -- Set the size of the text entry

    local npcLabel = vgui.Create("DLabel", rightPanel) -- Create a label for NPC selection
    npcLabel:SetText("Select NPC:") -- Set the text of the label
    npcLabel:SetPos(10, 70) -- Set the position of the label

    local npcDropdown = vgui.Create("DComboBox", rightPanel) -- Create a dropdown menu for NPC selection
    npcDropdown:SetPos(10, 90) -- Set the position of the dropdown menu
    npcDropdown:SetSize(150, 20) -- Set the size of the dropdown menu
    npcDropdown:SetValue("npc_citizen") -- Set the default value to "npc_citizen"


    -- Get the list of all NPCs and populate the dropdown menu
    local npcTable = list.Get("NPC")
    for npcClass, _ in pairs(npcTable) do
        npcDropdown:AddChoice(npcClass)
    end

    local apiKeyLabel = vgui.Create("DLabel", rightPanel) -- Create a label for the API key
    apiKeyLabel:SetText("API Key:") -- Set the text of the label
    apiKeyLabel:SetPos(10, 130) -- Set the position of the label

    local apiKeyEntry = vgui.Create("DTextEntry", rightPanel) -- Create a text entry for the API key
    apiKeyEntry:SetPos(10, 150) -- Set the position of the text entry
    apiKeyEntry:SetSize(150, 20) -- Set the size of the text entry
    apiKeyEntry:SetText(inputapikey) -- Set the default text of the text entry

    local createButton = vgui.Create("DButton", rightPanel) -- Create a button for creating the NPC
    createButton:SetText("Create NPC") -- Set the text of the button
    createButton:SetPos(10, 190) -- Set the position of the button
    createButton:SetSize(150, 30) -- Set the size of the button
    createButton.DoClick = function()
        inputapikey = apiKeyEntry:GetValue()
        -- Send API key
        net.Start("SendAPIKey")
        net.WriteString(apiKeyEntry:GetValue())
        net.SendToServer()

        -- Send AI personality
        net.Start("SendPersonality")
        net.WriteString(aiLinkEntry:GetValue())
        net.SendToServer()

        -- Send selected NPC class
        net.Start("SendSelectedNPC")
        net.WriteString(npcDropdown:GetValue())
        net.SendToServer()
    end
end
