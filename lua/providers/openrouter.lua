local openrouterProvider = {}

openrouterProvider.models = {
    
}

if SERVER then
    function openrouterProvider.request(npc, callback)
        local function correctFloatToInt(jsonString)
            return string.gsub(jsonString, '(%d+)%.0', '%1')
        end

        local requestBody = {
            model = 'huggingfaceh4/zephyr-7b-beta:free',
            messages = npc["history"],
            max_tokens = npc["max_tokens"], 
            temperature = npc["temperature"]
        }

        HTTP({
            url = "https://openrouter.ai/api/v1/chat/completions",
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
end

-- 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

return openrouterProvider