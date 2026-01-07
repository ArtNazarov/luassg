-- luassg_process_file.lua - Complete pipeline for a single XML file
local args = {...}

if #args < 6 then
    print("Usage: lua luassg_process_file.lua <entity_name> <entity_id> <xml_file> <template_content> <start_time> [constants_file]")
    os.exit(1)
end

local entity_name = args[1]
local entity_id = args[2]
local xml_file = args[3]
local template_content = args[4]:gsub("\\n", "\n"):gsub("\\r", "\r")
local start_time = tonumber(args[5])
local constants_file = args[6]

print("Processing: " .. entity_name .. "-" .. entity_id)

-- Load constants
local constants = {}
if constants_file then
    local file = io.open(constants_file, "r")
    if file then
        for line in file:lines() do
            local k, v = line:match("([^=]+)=(.+)")
            if k and v then
                constants[k] = v
            end
        end
        file:close()
    end
end

-- Step 1: Read and parse XML (Reader stage)
local xml_file_handle = io.open(xml_file, "r")
if not xml_file_handle then
    print("ERROR: Could not open XML file: " .. xml_file)
    os.exit(1)
end

local xml_content = xml_file_handle:read("*a")
xml_file_handle:close()

-- Parse XML
local entity = {
    tag = nil,
    fields = {},
    attrs = {}
}

-- Extract root tag
local roottag = xml_content:match("<(%w+)")
if roottag then
    entity.tag = roottag
end

-- Extract ID if present
local id = xml_content:match('id%s*=%s*[\'"]([^\'"]+)[\'"]')
if id then
    entity.attrs.id = id
end

-- Extract all fields
for field, value in xml_content:gmatch("<(%w+)>(.-)</%1>") do
    if field ~= entity.tag then
        entity.fields[field] = value:match("^%s*(.-)%s*$")
    end
end

-- Extract other attributes
for attr, value in xml_content:gmatch('(%w+)%s*=%s*[\'"]([^\'"]+)[\'"]') do
    if attr ~= "id" then
        entity.attrs[attr] = value
    end
end

-- Use ID from XML if available
local final_id = entity.attrs.id or entity_id or "unknown"
local final_entity_name = entity.tag or entity_name or "unknown"

-- Step 2: Perform substitution (Substitution stage)
local html = template_content

-- Replace CONST values
for const_name, const_value in pairs(constants) do
    local pattern = "__CONST%." .. const_name .. "__"
    html = html:gsub(pattern, const_value)
end

-- Replace entity fields
for field, value in pairs(entity.fields) do
    local placeholder = "{" .. final_entity_name .. "." .. field .. "}"
    html = html:gsub(placeholder, value)
end

-- Replace entity attributes
for attr, value in pairs(entity.attrs) do
    local placeholder = "{" .. final_entity_name .. "." .. attr .. "}"
    html = html:gsub(placeholder, value)
end

-- Step 3: Write HTML file (Writer stage)
os.execute("mkdir -p ./output 2>/dev/null")
local output_filename = "./output/" .. final_entity_name .. "-" .. final_id .. ".html"
local output_file = io.open(output_filename, "w")

if output_file then
    output_file:write(html)
    output_file:close()
    
    local end_time = os.clock() * 1000
    local processing_time = end_time - start_time
    
    print("  ✓ Written: " .. output_filename .. string.format(" (%.2f ms)", processing_time))
    return true
else
    print("  ✗ ERROR: Could not write file: " .. output_filename)
    return false
end