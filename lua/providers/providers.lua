local providers = {}

function providers.get(name)
    print(name)
    if name == "openai" then
        provider = include("providers/openai.lua")
    elseif name == "groq" then
        provider = include("providers/groq.lua")
    elseif name == "openrouter" then
        provider = include("providers/openrouter.lua")
    else
        error("Unsupported provider: " .. name) 
    end

    return provider
end

return providers