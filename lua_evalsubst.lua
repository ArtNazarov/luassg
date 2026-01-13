-- lua_evalsubst.lua - Evaluate Lua code fragments in text
local io = require("io")
local os = require("os")
local math = require("math")
local string = require("string")

-- Function to generate a random alphanumeric string
local function generateRandomId(length)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local result = ""
    for i = 1, length do
        local rand = math.random(1, #chars)
        result = result .. string.sub(chars, rand, rand)
    end
    return result
end

-- Main function to evaluate Lua code fragments and substitute them
function evaluateAndSubstitute(txt)
    -- Seed random number generator
    math.randomseed(os.time())
    
    -- Pattern to match [lua]...[/lua] blocks
    -- This pattern handles nested tags by using non-greedy matching
    local pattern = "%[lua%](.-)%[/lua%]"
    
    -- Function to process each match
    local function processMatch(luaCode)
        -- Generate unique filename
        local tempFileName
        local fileExists = true
        local attempts = 0
        local maxAttempts = 100
        
        -- Keep trying until we find a non-existent filename
        while fileExists and attempts < maxAttempts do
            local randomId = generateRandomId(16)
            tempFileName = "temp-" .. randomId .. ".lua"
            local file = io.open(tempFileName, "r")
            if file then
                file:close()
                -- File exists, try another name
                attempts = attempts + 1
            else
                fileExists = false
            end
        end
        
        if attempts >= maxAttempts then
            return "[ERROR: Could not generate unique temp filename]"
        end
        
        -- Create and write to temporary file with exclusive access
        local tempFile, err = io.open(tempFileName, "w")
        if not tempFile then
            return "[ERROR: Could not create temp file: " .. (err or "unknown") .. "]"
        end
        
        -- Write the Lua code to the file
        tempFile:write(luaCode)
        tempFile:close()
        
        -- Execute the Lua file and capture output
        local handle = io.popen("lua " .. tempFileName, "r")
        if not handle then
            os.remove(tempFileName)
            return "[ERROR: Could not execute Lua code]"
        end
        
        local res_lua = handle:read("*a")
        local success, errMsg, exitCode = handle:close()
        
        -- Immediately remove the temporary file
        os.remove(tempFileName)
        
        -- Check if execution was successful
        if not success then
            return "[ERROR: Lua execution failed: " .. (errMsg or "unknown") .. ", exit code: " .. (exitCode or "unknown") .. "]"
        end
        
        -- Clean up any trailing newline
        res_lua = string.gsub(res_lua, "\n$", "")
        
        return res_lua
    end
    
    -- Replace all occurrences of [lua]...[/lua] with their evaluated results
    local result = string.gsub(txt, pattern, processMatch)
    
    return result
end

-- Function to evaluate Lua code fragments in HTML content (with error handling)
function evaluateLuaFragments(html)
    local start_time = os.clock() * 1000
    
    -- Count how many Lua fragments we find
    local fragment_count = 0
    local pattern = "%[lua%]"
    for _ in string.gmatch(html, pattern) do
        fragment_count = fragment_count + 1
    end
    
    if fragment_count == 0 then
        return html, 0, 0  -- No fragments found, return original
    end
    
    print("    Processing " .. fragment_count .. " Lua fragment(s)...")
    
    -- Process the fragments
    local processed_html = evaluateAndSubstitute(html)
    
    local end_time = os.clock() * 1000
    local processing_time = end_time - start_time
    
    -- Count how many fragments were actually processed (by checking for errors)
    local processed_count = 0
    local error_count = 0
    
    -- Check for error markers in the output
    if string.find(processed_html, "%[ERROR:") then
        -- Count errors
        for _ in string.gmatch(processed_html, "%[ERROR:[^%]]+%]") do
            error_count = error_count + 1
        end
        processed_count = fragment_count - error_count
        print("    WARNING: " .. error_count .. " fragment(s) had errors")
    else
        processed_count = fragment_count
    end
    
    return processed_html, processed_count, error_count
end

-- Export the functions
return {
    evaluateAndSubstitute = evaluateAndSubstitute,
    evaluateLuaFragments = evaluateLuaFragments
}