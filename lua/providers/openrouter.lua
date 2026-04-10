--[[
    OpenRouter provider.
    Free models rotate monthly, so we fetch them at runtime from
    https://openrouter.ai/api/v1/models and filter by pricing.prompt == "0".
    A tiny hardcoded fallback list ships with the addon in case the fetch fails.
]]

local provider = {}

provider.id       = "openrouter"
provider.label    = "OpenRouter (free models available)"
provider.getKeyUrl = "https://openrouter.ai/keys"
provider.note     = "Free models rotate. Sign up and get a key, then pick a :free model."

-- Fallback preset — used only if the live fetch fails. These are known-good
-- as of the last addon update, but the live fetch supersedes them.
provider.modelOrder = {
    "openrouter/free",
    "meta-llama/llama-3.3-70b-instruct:free",
    "openai/gpt-oss-120b:free",
    "openai/gpt-oss-20b:free",
    "qwen/qwen3-next-80b-a3b-instruct:free",
    "z-ai/glm-4.5-air:free",
    "google/gemma-3-27b-it:free",
    "nousresearch/hermes-3-llama-3.1-405b:free",
    "cognitivecomputations/dolphin-mistral-24b-venice-edition:free",
}

local function defaults(label, ctxMax, reasoning, tools)
    return {
        label = label,
        max_tokens   = { min = 64, max = math.min(ctxMax or 8192, 32768), default = 2048 },
        temperature  = { min = 0, max = 2, default = 1 },
        reasoning    = reasoning and { "low", "medium", "high" } or nil,
        tool_support = tools == true,
    }
end

provider.models = {
    ["openrouter/free"]                                = defaults("Free Models Router (auto-pick)", 200000, true, true),
    ["meta-llama/llama-3.3-70b-instruct:free"]         = defaults("Llama 3.3 70B Instruct (free)", 65536, false, true),
    ["openai/gpt-oss-120b:free"]                       = defaults("GPT-OSS 120B (free, reasoning)", 131072, true, true),
    ["openai/gpt-oss-20b:free"]                        = defaults("GPT-OSS 20B (free, reasoning)", 131072, true, true),
    ["qwen/qwen3-next-80b-a3b-instruct:free"]          = defaults("Qwen3 Next 80B (free, huge ctx)", 262144, false, true),
    ["z-ai/glm-4.5-air:free"]                          = defaults("GLM 4.5 Air (free, reasoning)", 131072, true, true),
    ["google/gemma-3-27b-it:free"]                     = defaults("Gemma 3 27B (free)", 131072, false, false),
    ["nousresearch/hermes-3-llama-3.1-405b:free"]      = defaults("Hermes 3 405B (free, RP-tuned)", 131072, false, false),
    ["cognitivecomputations/dolphin-mistral-24b-venice-edition:free"] = defaults("Venice Uncensored 24B (free)", 32768, false, false),
}

if SERVER then
    local function buildBody(npc)
        local body = {
            model    = npc.model,
            messages = npc.history,
            max_tokens = npc.max_tokens,
        }
        if npc.temperature ~= nil then body.temperature = npc.temperature end
        if npc.reasoning and npc.reasoning ~= "" then
            body.reasoning = { effort = npc.reasoning }
        end
        return body
    end

    function provider.request(npc, callback)
        HTTP({
            url = "https://openrouter.ai/api/v1/chat/completions",
            method = "post",
            type = "application/json",
            headers = {
                ["Content-Type"]    = "application/json",
                ["Authorization"]   = "Bearer " .. (npc.apiKey or ""),
                ["HTTP-Referer"]    = "https://github.com/SonnyTaylor/AI-NPCs-GMod",
                ["X-Title"]         = "Garry's Mod AI NPCs",
            },
            body = util.TableToJSON(buildBody(npc)),
            success = function(code, respBody)
                AINPCS.DebugPrint("[AI-NPCs][OpenRouter] " .. tostring(code))
                local parsed = AINPCS.SafeJSON(respBody)
                if not parsed then
                    return callback("Invalid JSON from OpenRouter (HTTP " .. tostring(code) .. ")", nil)
                end
                callback(nil, parsed)
            end,
            failed = function(err)
                callback("HTTP error: " .. tostring(err), nil)
            end,
        })
    end

    -- ----------------------------------------------------------------
    -- Live free-model fetch. Runs on startup + once every 24h.
    -- Results are merged back into provider.models and a copy is sent
    -- to clients via the AINPC_OpenRouterModels net message.
    -- ----------------------------------------------------------------

    provider._fetchedAt   = 0
    provider._fetchedList = nil

    local MAX_CHUNK = 50000

    local function sendModelsTo(target)
        if not provider._fetchedList then return end
        local payload = util.TableToJSON(provider._fetchedList)
        local total = #payload
        local chunks = math.ceil(total / MAX_CHUNK)
        if chunks < 1 then chunks = 1 end

        for i = 1, chunks do
            local startByte = (i - 1) * MAX_CHUNK + 1
            local endByte   = math.min(i * MAX_CHUNK, total)
            local slice = string.sub(payload, startByte, endByte)
            net.Start("AINPC_OpenRouterModels")
            net.WriteUInt(i, 8)
            net.WriteUInt(chunks, 8)
            net.WriteUInt(#slice, 20)
            net.WriteData(slice, #slice)
            if target then net.Send(target) else net.Broadcast() end
        end
    end

    local function broadcastModels() sendModelsTo(nil) end

    function provider.refresh(onDone)
        local cv = GetConVar("ainpc_openrouter_autorefresh")
        if cv and cv:GetInt() == 0 then
            if onDone then onDone(false, "disabled") end
            return
        end

        HTTP({
            url = "https://openrouter.ai/api/v1/models",
            method = "get",
            headers = { ["Accept"] = "application/json" },
            success = function(code, body)
                if code ~= 200 then
                    AINPCS.DebugPrint("[AI-NPCs][OpenRouter] refresh HTTP " .. tostring(code))
                    if onDone then onDone(false, "http " .. tostring(code)) end
                    return
                end

                local parsed = AINPCS.SafeJSON(body)
                if not parsed or not parsed.data then
                    if onDone then onDone(false, "bad json") end
                    return
                end

                local freeList    = {}
                local freeOrder   = {}
                local freeModels  = {}

                for _, m in ipairs(parsed.data) do
                    local id = m.id or ""
                    local price = m.pricing or {}
                    local promptPrice = tonumber(price.prompt or "1") or 1
                    local complPrice  = tonumber(price.completion or "1") or 1

                    if promptPrice == 0 and complPrice == 0 and id ~= "" then
                        local sp = m.supported_parameters or {}
                        local hasReasoning, hasTools = false, false
                        for _, p in ipairs(sp) do
                            if p == "reasoning" or p == "include_reasoning" then hasReasoning = true end
                            if p == "tools" then hasTools = true end
                        end

                        local ctx = tonumber(m.context_length) or 8192
                        local nameLabel = m.name or id
                        if #nameLabel > 60 then nameLabel = string.sub(nameLabel, 1, 57) .. "…" end

                        local entry = {
                            id = id,
                            label = nameLabel,
                            max_tokens   = { min = 64, max = math.min(ctx, 32768), default = 2048 },
                            temperature  = { min = 0, max = 2, default = 1 },
                            tool_support = hasTools,
                        }
                        if hasReasoning then
                            entry.reasoning = { "low", "medium", "high" }
                        end
                        freeModels[id] = entry
                        table.insert(freeList, entry)
                    end
                end

                -- Sort: openrouter/free first, then by id
                table.sort(freeList, function(a, b)
                    if a.id == "openrouter/free" then return true end
                    if b.id == "openrouter/free" then return false end
                    return a.id < b.id
                end)

                for _, entry in ipairs(freeList) do
                    table.insert(freeOrder, entry.id)
                end

                if #freeOrder > 0 then
                    -- Always include the auto-router even if the API skipped it
                    if not freeModels["openrouter/free"] then
                        local r = {
                            id = "openrouter/free",
                            label = "Free Models Router (auto-pick)",
                            max_tokens  = { min = 64, max = 32768, default = 2048 },
                            temperature = { min = 0, max = 2, default = 1 },
                            tool_support = true,
                        }
                        freeModels["openrouter/free"] = r
                        table.insert(freeOrder, 1, "openrouter/free")
                    end

                    provider.modelOrder = freeOrder
                    provider.models     = freeModels
                    provider._fetchedAt = os.time()
                    provider._fetchedList = {
                        order  = freeOrder,
                        models = freeModels,
                    }
                    AINPCS.DebugPrint("[AI-NPCs][OpenRouter] loaded " .. #freeOrder .. " free models")
                    broadcastModels()
                    if onDone then onDone(true) end
                else
                    if onDone then onDone(false, "no free models") end
                end
            end,
            failed = function(err)
                AINPCS.DebugPrint("[AI-NPCs][OpenRouter] refresh failed: " .. tostring(err))
                if onDone then onDone(false, err) end
            end,
        })
    end

    -- Kick off a refresh on startup (5s delay so HTTP is ready).
    hook.Add("Initialize", "AINPC_OpenRouterFirstRefresh", function()
        timer.Simple(5, function() provider.refresh() end)
    end)

    -- Refresh once a day.
    timer.Create("AINPC_OpenRouterRefresh", 24 * 60 * 60, 0, function()
        provider.refresh()
    end)

    -- Send current models to any player who joins after refresh.
    hook.Add("PlayerInitialSpawn", "AINPC_OpenRouterSendCache", function(ply)
        if not provider._fetchedList then return end
        timer.Simple(3, function()
            if not IsValid(ply) then return end
            sendModelsTo(ply)
        end)
    end)
end

return provider
