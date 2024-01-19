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
    local frame = vgui.Create("DFrame")
    frame:SetSize(300, 200)
    frame:SetTitle("GMod GUI")
    frame:SetVisible(true)
    frame:Center()

    local button = vgui.Create("DButton", frame)
    button:SetText("Click me!")
    button:SetPos(100, 100)
    button:SetSize(100, 50)
    button.DoClick = function()
        print("Button clicked!")
    end

    frame:MakePopup()
end
