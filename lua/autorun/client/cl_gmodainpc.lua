-- Context menu button
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


    local nameLabel = vgui.Create("DLabel", frame) -- Create a label for the AI personality
    nameLabel:SetText("AI Personality:") -- Set the text of the label
    nameLabel:SetPos(220, 30) -- Set the position of the label

    local aiLinkEntry = vgui.Create("DTextEntry", frame) -- Create a text entry for the AI personality
    aiLinkEntry:SetPos(220, 50) -- Set the position of the text entry
    aiLinkEntry:SetSize(150, 20) -- Set the size of the text entry

    local apiKeyLabel = vgui.Create("DLabel", frame) -- Create a label for the API key
    apiKeyLabel:SetText("API Key:") -- Set the text of the label
    apiKeyLabel:SetPos(220, 80) -- Set the position of the label

    local apiKeyEntry = vgui.Create("DTextEntry", frame) -- Create a text entry for the API key
    apiKeyEntry:SetPos(220, 100) -- Set the position of the text entry
    apiKeyEntry:SetSize(150, 20) -- Set the size of the text entry

    local createButton = vgui.Create("DButton", frame) -- Create a button for creating the NPC
    createButton:SetText("Create NPC") -- Set the text of the button
    createButton:SetPos(220, 130) -- Set the position of the button
    createButton:SetSize(150, 30) -- Set the size of the button
    createButton.DoClick = function()
        local apiKey = apiKeyEntry:GetValue() -- Get the API key from the text entry'
        net.Start("sendApiKey") -- Start sending the net message
        net.WriteType(key) -- Write the variable to the message
        net.SendToServer() -- Send the message to the server
    end
end

