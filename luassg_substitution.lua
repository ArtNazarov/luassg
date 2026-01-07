-- luassg_substitution.lua - Simple file-based version
print("luassg_substitution - Performing placeholder substitution...")

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
    template = nil,
    fields = {},
    attrs = {},
    constants = {},
    start_time = nil
}

local section = nil
for line in file:lines() do
    if line == "FIELDS_BEGIN" then
        section = "fields"
    elseif line == "FIELDS_END" then
        section = nil
    elseif line == "ATTRS_BEGIN" then
        section = "attrs"
    elseif line == "ATTRS_END" then
        section = nil
    elseif line == "CONSTANTS_BEGIN" then
        section = "constants"
    elseif line == "CONSTANTS_END" then
        section = nil
    else
        local k, v = line:match("([^=]+)=(.+)")
        if k and v then
            if k == "ENTITY_NAME" then
                data.entity_name = v
            elseif k == "ENTITY_ID" then
                data.entity_id = v
            elseif k == "TEMPLATE" then
                data.template = v:gsub("\\n", "\n"):gsub("\\r", "\r")
            elseif k == "START_TIME" then
                data.start_time = tonumber(v)
            elseif section then
                if section == "fields" or section == "attrs" then
                    v = v:gsub("\\n", "\n"):gsub("\\r", "\r")
                end
                if section == "fields" then
                    data.fields[k] = v
                elseif section == "attrs" then
                    data.attrs[k] = v
                elseif section == "constants" then
                    data.constants[k] = v
                end
            end
        end
    end
end
file:close()

-- Clean up temp file
os.remove(temp_file)

-- Validate data
if not data.template then
    print("ERROR: No template to process")
    os.exit(1)
end

if not data.entity_name then
    print("ERROR: No entity name")
    os.exit(1)
end

print("  Processing: " .. data.entity_name .. "-" .. (data.entity_id or "unknown"))

-- Perform substitution
local html = data.template

-- Replace CONST values
for const_name, const_value in pairs(data.constants) do
    local pattern = "__CONST%." .. const_name .. "__"
    html = html:gsub(pattern, const_value)
end

-- Replace entity fields
for field, value in pairs(data.fields) do
    local placeholder = "{" .. data.entity_name .. "." .. field .. "}"
    html = html:gsub(placeholder, value)
end

-- Replace entity attributes
for attr, value in pairs(data.attrs) do
    local placeholder = "{" .. data.entity_name .. "." .. attr .. "}"
    html = html:gsub(placeholder, value)
end

-- Prepare data for writer
local writer_temp = os.tmpname()
local writer_file = io.open(writer_temp, "w")

if writer_file then
    writer_file:write("ENTITY_NAME=" .. data.entity_name .. "\n")
    writer_file:write("ENTITY_ID=" .. (data.entity_id or "unknown") .. "\n")
    writer_file:write("HTML_CONTENT=" .. html:gsub("\n", "\\n"):gsub("\r", "\\r") .. "\n")
    writer_file:write("START_TIME=" .. (data.start_time or os.clock() * 1000) .. "\n")
    writer_file:close()
    
    -- Launch writer
    local writer_cmd = string.format('lua luassg_writer.lua "%s"', writer_temp)
    os.execute(writer_cmd)
    
    -- Clean up
    os.remove(writer_temp)
else
    print("ERROR: Could not create temp file for writer")
end