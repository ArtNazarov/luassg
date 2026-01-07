-- luassg_writer.lua - Simple file-based version
print("luassg_writer - Writing HTML file...")

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

-- Ensure output directory exists
os.execute("mkdir -p ./output 2>/dev/null")

-- Create output filename
local entity_id = data.entity_id or "unknown"
local output_filename = "./output/" .. data.entity_name .. "-" .. entity_id .. ".html"

-- Write file
local output_file = io.open(output_filename, "w")
if output_file then
    output_file:write(data.html_content)
    output_file:close()
    
    local end_time = os.clock() * 1000
    local processing_time = end_time - (data.start_time or end_time)
    
    print("  ✓ Written: " .. output_filename .. string.format(" (%.2f ms)", processing_time))
    return true
else
    print("  ✗ ERROR: Could not write file: " .. output_filename)
    return false
end