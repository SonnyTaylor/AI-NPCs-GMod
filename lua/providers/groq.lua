local groqProvider = {}

groqProvider.models = {
    "gemma2-9b-it",
    "llama-3.3-70b-versatile",
    "llama-3.1-8b-instant",
    "llama3-70b-8192",
    "llama3-8b-8192",
    "mixtral-8x7b-32768"
}

function groqProvider.request(npc, callback)
    local function correctFloatToInt(jsonString)
        return string.gsub(jsonString, '(%d+)%.0', '%1')
    end

    local requestBody = {
        model = 'llama-3.1-8b-instant',
        messages = npc["history"],
        max_tokens = npc["max_tokens"], 
        temperature = npc["temperature"]
    }

    HTTP({
        url = "https://api.groq.com/openai/v1/chat/completions",
        type = "application/json",
        method = "post",
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. npc["apiKey"] -- Access the API key from the Global table
        },
        body = correctFloatToInt(util.TableToJSON(requestBody)), -- tableToJSON changes integers to float

        success = function(code, body, headers)
            -- Parse the JSON response from the GPT-3 API
            local response = util.JSONToTable(body)

            callback(nil, response)
        end,
        failed = function(err)
            -- Print an error message if the HTTP request fails
            callback("HTTP Error: " .. err, nil)
        end
    })
end

return groqProvider