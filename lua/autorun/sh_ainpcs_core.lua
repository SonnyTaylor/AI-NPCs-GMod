--[[
    AI NPCs — shared core
    Runs on both client and server. Registers network strings, constants,
    shared helpers, and ships provider files + client files to the client.
]]

AINPCS = AINPCS or {}
AINPCS.Version = "2.0.0"

AINPCS.NetStrings = {
    "AINPC_SpawnRequest",
    "AINPC_SpawnResult",
    "AINPC_ModelPreview",
    "AINPC_ModelPreviewResponse",
    "AINPC_ChatRequest",
    "AINPC_ChatReply",
    "AINPC_OpenChatUI",
    "AINPC_TTSPlay",
    "AINPC_Toast",
    "AINPC_OpenRouterModels",
}

AINPCS.Defaults = {
    MaxHistoryTurns = 16,
    InteractRange = 140,
    ProximityRange = 220,
    ChatCooldownSeconds = 1.5,
    SpawnCooldownSeconds = 5,
    MaxNPCsPerPlayer = 3,
    RequestTimeout = 60,
}

if SERVER then
    AddCSLuaFile("autorun/sh_ainpcs_core.lua")
    AddCSLuaFile("autorun/sh_ainpcs_debug.lua")
    AddCSLuaFile("autorun/client/cl_gmodainpc.lua")
    AddCSLuaFile("autorun/client/cl_ainpcs_interact.lua")
    AddCSLuaFile("autorun/client/cl_ainpcs_hud.lua")
    AddCSLuaFile("providers/providers.lua")
    AddCSLuaFile("providers/openai.lua")
    AddCSLuaFile("providers/groq.lua")
    AddCSLuaFile("providers/openrouter.lua")
    AddCSLuaFile("providers/ollama.lua")
    AddCSLuaFile("providers/deepseek.lua")

    for _, name in ipairs(AINPCS.NetStrings) do
        util.AddNetworkString(name)
    end
end

-- String helpers -----------------------------------------------------------

function AINPCS.Trim(str)
    if not str then return "" end
    return (string.gsub(str, "^%s*(.-)%s*$", "%1"))
end

function AINPCS.IsBlank(str)
    return not str or AINPCS.Trim(str) == ""
end

function AINPCS.Truncate(str, limit)
    if not str then return "" end
    if #str <= limit then return str end
    return string.sub(str, 1, limit - 1) .. "…"
end

-- Sanitise a URL fragment so we never leak keys into logs or chat.
function AINPCS.RedactKey(str)
    if not str or str == "" then return "<empty>" end
    if #str <= 8 then return "<redacted>" end
    return string.sub(str, 1, 4) .. "…" .. string.sub(str, -4)
end

-- Accepts "host", "host:port", "http://host", "https://host/", etc. and
-- returns a normalised "scheme://host[:port]" with no trailing slash.
function AINPCS.NormaliseHostname(raw, defaultScheme)
    raw = AINPCS.Trim(raw or "")
    if raw == "" then return "" end

    local scheme, rest = string.match(raw, "^(https?)://(.*)$")
    if not scheme then
        scheme = defaultScheme or "http"
        rest = raw
    end

    rest = string.gsub(rest, "/+$", "")
    return scheme .. "://" .. rest
end

-- Strict JSON parse that swallows nil gracefully.
function AINPCS.SafeJSON(body)
    if not body or body == "" then return nil end
    local ok, tbl = pcall(util.JSONToTable, body)
    if not ok then return nil end
    return tbl
end

-- History trimming — keeps the system prompt plus the last N turns.
function AINPCS.TrimHistory(history, maxTurns)
    if not history or #history <= 1 then return history end
    maxTurns = maxTurns or AINPCS.Defaults.MaxHistoryTurns
    local maxMessages = maxTurns * 2

    if #history - 1 <= maxMessages then return history end

    local trimmed = { history[1] }
    local start = #history - maxMessages + 1
    if start < 2 then start = 2 end
    for i = start, #history do
        table.insert(trimmed, history[i])
    end
    return trimmed
end

return AINPCS
