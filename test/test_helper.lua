-- test_helper.lua
-- Mock Baud framework functions for testing triggers

-- Set SCRIPT_DIR for tests (Baud sets this automatically, tests run from project root)
SCRIPT_DIR = "./"

local M = {}

-- Storage for registered triggers and aliases
M.triggers = {}
M.aliases = {}

-- Track function calls for verification
M.sendCalls = {}
M.echoCalls = {}

-- Convert regex pattern to Lua pattern
-- This handles common regex syntax used in the triggers
local function regexToLuaPattern(pattern)
    local luaPattern = pattern

    -- Remove anchors (^ and $) - we'll handle them separately
    local hasStart = pattern:sub(1, 1) == "^"
    local hasEnd = pattern:sub(-1) == "$"

    if hasStart then
        luaPattern = luaPattern:sub(2)
    end
    if hasEnd then
        luaPattern = luaPattern:sub(1, -2)
    end

    -- Escape Lua magic characters that aren't regex special
    -- (but be careful not to double-escape)
    luaPattern = luaPattern:gsub("%%", "%%%%")  -- % -> %%

    -- Convert regex to Lua patterns
    luaPattern = luaPattern:gsub("\\d", "%%d")       -- \d -> %d
    luaPattern = luaPattern:gsub("\\s", "%%s")       -- \s -> %s
    luaPattern = luaPattern:gsub("\\w", "%%w")       -- \w -> %w
    luaPattern = luaPattern:gsub("\\%(", "%%(")      -- \( -> %(
    luaPattern = luaPattern:gsub("\\%)", "%%)")      -- \) -> %)
    luaPattern = luaPattern:gsub("\\%?", "%%?")      -- \? -> %?
    luaPattern = luaPattern:gsub("\\%.", "%%.")      -- \. -> %.

    -- Handle dots that should be literal (common in the patterns)
    -- Note: This is tricky - in regex . means any char, but many of our patterns
    -- use literal dots. We'll leave . as-is since Lua's . also means any char.

    -- Re-add anchors
    if hasStart then
        luaPattern = "^" .. luaPattern
    end
    if hasEnd then
        luaPattern = luaPattern .. "$"
    end

    return luaPattern
end

-- Mock createTrigger: stores pattern and callback for later simulation
function createTrigger(pattern, callback, options)
    local luaPattern = regexToLuaPattern(pattern)
    table.insert(M.triggers, {
        pattern = luaPattern,
        originalPattern = pattern,
        callback = callback,
        options = options or {}
    })
end

-- Mock createAlias: stores pattern and callback
function createAlias(pattern, callback, options)
    table.insert(M.aliases, {
        pattern = pattern,
        callback = callback,
        options = options or {}
    })
end

-- Mock setStatus: no-op for testing
function setStatus(segmentsOrFunction)
end

-- Mock send: records calls for verification
function send(text)
    table.insert(M.sendCalls, text)
end

-- Mock echo: records calls for verification
function echo(text)
    table.insert(M.echoCalls, text)
end

-- Test utility: simulate a line of text and fire matching triggers
function M.simulateLine(text)
    for _, trigger in ipairs(M.triggers) do
        local matches = {string.match(text, trigger.pattern)}
        if #matches > 0 or string.match(text, trigger.pattern) then
            -- For patterns without capture groups, matches will be empty
            -- but we still need to fire the trigger
            if #matches == 0 and string.match(text, trigger.pattern) then
                matches = {}
            end
            -- Prepend the full match text as matches[1] for compatibility
            table.insert(matches, 1, text)
            trigger.callback(matches)
        end
    end
end

-- Reset all state between tests
function M.resetAll()
    -- Clear tables in place to maintain references
    for k in pairs(M.triggers) do M.triggers[k] = nil end
    for k in pairs(M.aliases) do M.aliases[k] = nil end
    for k in pairs(M.sendCalls) do M.sendCalls[k] = nil end
    for k in pairs(M.echoCalls) do M.echoCalls[k] = nil end
    -- Reset gePackage state
    gePackage = nil
end

-- Helper to check if send was called with specific text
function M.wasSendCalledWith(text)
    for _, call in ipairs(M.sendCalls) do
        if call == text then
            return true
        end
    end
    return false
end

-- Helper to check if echo was called with specific text
function M.wasEchoCalledWith(text)
    for _, call in ipairs(M.echoCalls) do
        if call == text then
            return true
        end
    end
    return false
end

-- Helper to get the last send call
function M.getLastSendCall()
    return M.sendCalls[#M.sendCalls]
end

-- Helper to get the last echo call
function M.getLastEchoCall()
    return M.echoCalls[#M.echoCalls]
end

return M
