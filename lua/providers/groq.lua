local groqProvider = {}

groqProvider.models = {
    "gemma2-9b-it",
    "llama-3.3-70b-versatile",
    "llama-3.1-8b-instant",
    "llama3-70b-8192",
    "llama3-8b-8192",
    "mixtral-8x7b-32768",
    "allam-2-7b",
    "deepseek-r1-distill-llama-70b",
    "meta-llama/llama-4-maverick-17b-128e-instruct",
    "meta-llama/llama-4-scout-17b-16e-instruct",
    "mistral-saba-24b",
    "qwen-qwq-32b"
}

if SERVER then
    function groqProvider.request(npc, callback)
        local function correctFloatToInt(jsonString)
            return string.gsub(jsonString, '(%d+)%.0', '%1')
        end

        local requestBody = {
            model = npc["model"],
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
end

return groqProvider