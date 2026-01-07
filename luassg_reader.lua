-- luassg_reader.lua - Simple file-based version
print("luassg_reader - Reading XML file...")

-- Get temp file from command line
local args = {...}
local temp_file = args[1]

if not temp_file or temp_file == "" then
    print("ERROR: No data file provided")
    os.exit(1)
end

-- Helper function to count table elements
local function tableCount(tbl)
    local count = 0
    if tbl then
        for _ in pairs(tbl) do
            count = count + 1
        end
    end
    return count
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
    xml_file = nil,
    template = nil,
    constants = {},
    start_time = nil
}

local in_constants = false
for line in file:lines() do
    if line == "CONSTANTS_BEGIN" then
        in_constants = true
    elseif line == "CONSTANTS_END" then
        in_constants = false
    elseif in_constants then
        local k, v = line:match("([^=]+)=(.+)")
        if k and v then
            data.constants[k] = v
        end
    else
        local k, v = line:match("([^=]+)=(.+)")
        if k and v then
            if k == "TEMPLATE" then
                -- Unescape template
                data.template = v:gsub("\\n", "\n"):gsub("\\r", "\r")
            elseif k == "ENTITY_NAME" then
                data.entity_name = v
            elseif k == "ENTITY_ID" then
                data.entity_id = v
            elseif k == "XML_FILE" then
                data.xml_file = v
            elseif k == "START_TIME" then
                data.start_time = tonumber(v)
            end
        end
    end
end
file:close()

-- Clean up temp file
os.remove(temp_file)

-- Validate data
if not data.xml_file then
    print("ERROR: No XML file specified")
    os.exit(1)
end

if not data.template then
    print("ERROR: No template specified")
    os.exit(1)
end

-- Read XML file
local xml_file = io.open(data.xml_file, "r")
if not xml_file then
    print("ERROR: Could not open XML file: " .. data.xml_file)
    os.exit(1)
end

local xml_content = xml_file:read("*a")
xml_file:close()

-- Parse XML (simplified)
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
local final_id = entity.attrs.id or data.entity_id or "unknown"
local final_entity_name = entity.tag or data.entity_name or "unknown"

print("  Read: " .. data.xml_file .. " -> " .. final_entity_name .. "-" .. final_id)
print("  Fields found: " .. tableCount(entity.fields))
print("  Attributes: " .. tableCount(entity.attrs))

-- Prepare data for substitution
local sub_temp = os.tmpname()
local sub_file = io.open(sub_temp, "w")

if sub_file then
    sub_file:write("ENTITY_NAME=" .. final_entity_name .. "\n")
    sub_file:write("ENTITY_ID=" .. final_id .. "\n")
    sub_file:write("TEMPLATE=" .. data.template:gsub("\n", "\\n"):gsub("\r", "\\r") .. "\n")
    sub_file:write("START_TIME=" .. (data.start_time or os.clock() * 1000) .. "\n")
    
    -- Write fields
    sub_file:write("FIELDS_BEGIN\n")
    for field, value in pairs(entity.fields) do
        sub_file:write(field .. "=" .. value:gsub("\n", "\\n"):gsub("\r", "\\r") .. "\n")
    end
    sub_file:write("FIELDS_END\n")
    
    -- Write attributes
    sub_file:write("ATTRS_BEGIN\n")
    for attr, value in pairs(entity.attrs) do
        sub_file:write(attr .. "=" .. value .. "\n")
    end
    sub_file:write("ATTRS_END\n")
    
    -- Write constants
    sub_file:write("CONSTANTS_BEGIN\n")
    for const_name, const_value in pairs(data.constants) do
        sub_file:write(const_name .. "=" .. const_value .. "\n")
    end
    sub_file:write("CONSTANTS_END\n")
    
    sub_file:close()
    
    -- Launch substitution
    local subst_cmd = string.format('lua luassg_substitution.lua "%s"', sub_temp)
    os.execute(subst_cmd)
    
    -- Clean up
    os.remove(sub_temp)
else
    print("ERROR: Could not create temp file for substitution")
end