local ollamaProvider = {}

function ollamaProvider.request(npc, callback)
    local function correctFloatToInt(jsonString)
        return string.gsub(jsonString, '(%d+)%.0', '%1')
    end

    if not npc["hostname"] then
        ErrorNoHalt("Hostname not defined")
    end

    local requestBody = {
        model = "llama3:latest",
        messages = npc["history"],
        max_tokens = npc["max_tokens"], 
        temperature = npc["temperature"],
        stream = false
    }

    HTTP({
        url = "http://" .. npc["hostname"] .. "/api/chat",
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

            -- Add choices list to match ollama output to GPT output
            response.choices = {
                {
                    message = {
                        role = response.message.role,
                        content = response.message.content
                    }
                }
            }

            callback(nil, response)
        end,
        failed = function(err)
            -- Print an error message if the HTTP request fails
            callback("HTTP Error: " .. err, nil)
        end
    })
end

return ollamaProvider