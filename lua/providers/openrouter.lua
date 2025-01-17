local openrouterProvider = {}

function openrouterProvider.request(apiKey, model, messages, max_tokens, temperature, callback)
    local function correctFloatToInt(jsonString)
        return string.gsub(jsonString, '(%d+)%.0', '%1')
    end

    local requestBody = {
        model = 'huggingfaceh4/zephyr-7b-beta:free',
        messages = messages,
        max_tokens = max_tokens, 
        temperature = temperature
    }

    HTTP({
        url = "https://openrouter.ai/api/v1/chat/completions",
        type = "application/json",
        method = "post",
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. apiKey -- Access the API key from the Global table
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

return openrouterProvider