--[[
    Ollama provider (self-hosted). Uses the OpenAI-compatible
    /v1/chat/completions endpoint so max_tokens/temperature work natively
    and the response shape matches every other provider.
]]

local provider = {}

provider.id       = "ollama"
provider.label    = "Ollama (self-hosted)"
provider.getKeyUrl = "https://ollama.com/download"
provider.note     = "Runs locally. Set Hostname to your Ollama host (e.g. 127.0.0.1:11434). API key is optional."

provider.requiresHostname = true
provider.allowCustomModel = true

-- No default model list — users type the model they've pulled locally.
provider.models     = {}
provider.modelOrder = {}

if SERVER then
    function provider.request(npc, callback)
        local host = AINPCS.NormaliseHostname(npc.hostname or "", "http")
        if host == "" then
            return callback("Ollama hostname not set. Open the AI NPCs panel and fill in Hostname.", nil)
        end

        local body = {
            model    = npc.model,
            messages = npc.history,
            stream   = false,
        }
        if npc.max_tokens then body.max_tokens = npc.max_tokens end
        if npc.temperature ~= nil then body.temperature = npc.temperature end

        local headers = { ["Content-Type"] = "application/json" }
        if not AINPCS.IsBlank(npc.apiKey) then
            headers["Authorization"] = "Bearer " .. npc.apiKey
        end

        HTTP({
            url = host .. "/v1/chat/completions",
            method = "post",
            type = "application/json",
            headers = headers,
            body = util.TableToJSON(body),
            success = function(code, respBody)
                AINPCS.DebugPrint("[AI-NPCs][Ollama] " .. tostring(code))
                local parsed = AINPCS.SafeJSON(respBody)
                if not parsed then
                    return callback("Invalid JSON from Ollama (HTTP " .. tostring(code) .. "). Is the host URL correct?", nil)
                end
                callback(nil, parsed)
            end,
            failed = function(err)
                callback("HTTP error: " .. tostring(err) .. " (is Ollama running at " .. host .. "?)", nil)
            end,
        })
    end
end

return provider
