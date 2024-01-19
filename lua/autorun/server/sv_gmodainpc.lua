local meta = FindMetaTable("Player")
local apiKey = "sk-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" -- Your OpenAI API key here

meta.sendGPTRequest = function(this, text)
    HTTP({
        url = 'https://api.openai.com/v1/chat/completions',
        type = 'application/json',
        method = 'post',
        headers = {
            ['Content-Type'] = 'application/json',
            ['Authorization'] = 'Bearer '..apiKey,
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
    end
end)