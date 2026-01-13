-- luassg_writer.lua - Simple file-based version with Lua fragment support
print("luassg_writer - Writing HTML file...")

-- Load Lua evaluation module
local evalsubst
local success, err = pcall(function()
    evalsubst = require("lua_evalsubst")
end)

if not success then
    print("ERROR: Failed to load lua_evalsubst module: " .. (err or "unknown"))
    print("Make sure lua_evalsubst.lua is in the same directory or Lua path")
    os.exit(1)
end

-- Get temp file from command line
local args = {...}
local temp_file = args[1]

if not temp_file or temp_file == "" then
    print("ERROR: No data file provided")
    os.exit(1)
end

-- Read data from temp file
local file = io.open(temp_file, "r")
if not file then
    print("ERROR: Could not open data file: " .. temp_file)
    os.exit(1)
end

local data = {
    entity_name = nil,
    entity_id = nil,
    html_content = nil,
    start_time = nil
}

for line in file:lines() do
    local k, v = line:match("([^=]+)=(.+)")
    if k and v then
        if k == "ENTITY_NAME" then
            data.entity_name = v
        elseif k == "ENTITY_ID" then
            data.entity_id = v
        elseif k == "HTML_CONTENT" then
            data.html_content = v:gsub("\\n", "\n"):gsub("\\r", "\r")
        elseif k == "START_TIME" then
            data.start_time = tonumber(v)
        end
    end
end
file:close()

-- Clean up temp file
os.remove(temp_file)

-- Validate data
if not data.entity_name then
    print("ERROR: No entity name")
    os.exit(1)
end

if not data.html_content then
    print("ERROR: No HTML content")
    os.exit(1)
end

-- Check if HTML contains Lua fragments
local has_lua_fragments = false
if data.html_content:find("%[lua%]") then
    has_lua_fragments = true
    print("  Found Lua fragments in HTML for " .. data.entity_name .. "-" .. (data.entity_id or "unknown"))
end

-- Process Lua fragments in the HTML content if present
local processed_html = data.html_content
local fragment_count = 0
local error_count = 0
local fragment_processing_time = 0

if has_lua_fragments then
    print("  Processing Lua fragments for " .. data.entity_name .. "-" .. (data.entity_id or "unknown") .. "...")
    local start_fragment_time = os.clock() * 1000
    
    -- Count fragments before processing
    fragment_count = 0
    for _ in data.html_content:gmatch("%[lua%]") do
        fragment_count = fragment_count + 1
    end
    
    -- Process the fragments
    processed_html, processed_count, fragment_errors = evalsubst.evaluateLuaFragments(data.html_content)
    error_count = fragment_errors or 0
    
    local end_fragment_time = os.clock() * 1000
    fragment_processing_time = end_fragment_time - start_fragment_time
    
    if fragment_count > 0 then
        local success_count = fragment_count - error_count
        print("    Processed " .. fragment_count .. " Lua fragment(s): " .. 
              success_count .. " successful, " .. error_count .. " errors")
        print(string.format("    Fragment processing time: %.2f ms", fragment_processing_time))
    end
end

-- Ensure output directory exists
os.execute("mkdir -p ./output 2>/dev/null")

-- Create output filename
local entity_id = data.entity_id or "unknown"
local output_filename = "./output/" .. data.entity_name .. "-" .. entity_id .. ".html"

-- Write file
local output_file = io.open(output_filename, "w")
if output_file then
    output_file:write(processed_html)
    output_file:close()
    
    local end_time = os.clock() * 1000
    local total_processing_time = end_time - (data.start_time or end_time)
    local writer_stage_time = total_processing_time - fragment_processing_time
    
    -- Build status message with detailed timing
    local status_parts = {}
    table.insert(status_parts, string.format("(%.2f ms total", total_processing_time))
    table.insert(status_parts, string.format("writer: %.2f ms", writer_stage_time))
    
    if fragment_count > 0 then
        table.insert(status_parts, string.format("lua: %.2f ms", fragment_processing_time))
        table.insert(status_parts, string.format("%d frags", fragment_count))
        if error_count > 0 then
            table.insert(status_parts, string.format("%d errs", error_count))
        end
    end
    
    local status_msg = table.concat(status_parts, ", ") .. ")"
    
    print("  ✓ Written: " .. output_filename .. " " .. status_msg)
    
    -- Also write a summary line for the scanner to parse
    local summary_file = io.open("/tmp/luassg_summary.log", "a")
    if summary_file then
        summary_file:write(data.entity_name .. "-" .. entity_id .. 
                          "|" .. fragment_count .. 
                          "|" .. error_count .. 
                          "|" .. string.format("%.2f", fragment_processing_time) .. "\n")
        summary_file:close()
    end
    
    return true
else
    print("  ✗ ERROR: Could not write file: " .. output_filename)
    return false
end