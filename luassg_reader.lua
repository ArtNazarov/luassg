-- luassg_reader.lua - Improved XML parsing
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

-- Improved XML parsing function
local function parseXMLBetter(xml_content)
    local entity = {
        tag = nil,
        fields = {},
        attrs = {}
    }

    -- Extract root tag name (handles XML declaration)
    local root_start = xml_content:find("<%w")
    if root_start then
        local tag_start = xml_content:sub(root_start + 1):match("^([%w_]+)")
        entity.tag = tag_start
    end

    if not entity.tag then
        print("  WARNING: Could not find root tag in XML")
        return entity
    end

    -- Extract attributes from opening tag
    local opening_tag = xml_content:match("<" .. entity.tag .. "%s*(.-)>")
    if opening_tag then
        -- Extract id attribute
        local id = opening_tag:match('id%s*=%s*["\']([^"\']+)["\']')
        if id then
            entity.attrs.id = id
        end

        -- Extract other attributes
        for attr, value in opening_tag:gmatch('(%w+)%s*=%s*["\']([^"\']+)["\']') do
            if attr ~= "id" then
                entity.attrs[attr] = value
            end
        end
    end

    -- Extract all content between root tags
    local root_content = xml_content:match("<" .. entity.tag .. "[^>]*>(.-)</" .. entity.tag .. ">")
    if not root_content then
        print("  WARNING: Could not extract content between root tags")
        return entity
    end

    -- Parse all child elements
    local pos = 1
    while pos <= #root_content do
        -- Find next opening tag
        local tag_start, tag_end, tag_name = root_content:find("<(%w+)[^>]*>", pos)
        if not tag_start then break end

        -- Find corresponding closing tag
        local closing_pattern = "</" .. tag_name .. ">"
        local content_start = tag_end + 1
        local content_end = root_content:find(closing_pattern, content_start)

        if content_end then
            local field_content = root_content:sub(content_start, content_end - 1)
            -- Clean up the content (remove CDATA if present, trim whitespace)
            field_content = field_content:gsub("^%s*<!%[CDATA%[(.-)%]%]>%s*$", "%1")
            field_content = field_content:match("^%s*(.-)%s*$") or field_content

            entity.fields[tag_name] = field_content
            pos = content_end + #closing_pattern
        else
            -- Self-closing tag or malformed
            pos = tag_end + 1
        end
    end

    -- Alternative simpler parsing for well-formed XML
    if tableCount(entity.fields) == 0 then
        print("  Trying alternative parsing...")
        for tag_name in root_content:gmatch("<(%w+)>") do
            local pattern = "<" .. tag_name .. ">(.-)</" .. tag_name .. ">"
            local value = root_content:match(pattern)
            if value then
                entity.fields[tag_name] = value:match("^%s*(.-)%s*$")
            end
        end
    end

    return entity
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

-- Parse XML with improved parser
print("  Parsing XML: " .. data.xml_file)
local entity = parseXMLBetter(xml_content)

if not entity.tag then
    print("  ERROR: Failed to parse XML")
    print("  XML content preview: " .. xml_content:sub(1, 200) .. "...")
    os.exit(1)
end

print("  Root tag: " .. entity.tag)
print("  Fields found: " .. tableCount(entity.fields))

-- Debug: List all fields found
if tableCount(entity.fields) > 0 then
    print("  Field list:")
    for field, value in pairs(entity.fields) do
        print("    - " .. field .. ": " .. (value:sub(1, 50) .. (value:len() > 50 and "..." or "")))
    end
else
    print("  WARNING: No fields parsed from XML")
end

-- Use ID from XML if available
local final_id = entity.attrs.id or data.entity_id or "unknown"
local final_entity_name = entity.tag or data.entity_name or "unknown"

-- Verify entity name matches expected
if final_entity_name ~= data.entity_name then
    print("  WARNING: Entity name mismatch. Expected: " .. data.entity_name .. ", Got: " .. final_entity_name)
    print("  Using: " .. final_entity_name)
end

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

    -- Pass to substitution process
    local subst_cmd = string.format('lua luassg_substitution.lua "%s"', sub_temp)
    os.execute(subst_cmd)

    -- Clean up
    os.remove(sub_temp)
else
    print("ERROR: Could not create temp file for substitution")
end
