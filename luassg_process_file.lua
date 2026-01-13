-- luassg_process_file.lua - Complete pipeline for a single XML file
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
    if next(entity.fields) == nil then  -- Check if table is empty
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

-- Step 1: Read and parse XML (Reader stage)
local xml_file_handle = io.open(xml_file, "r")
if not xml_file_handle then
    print("ERROR: Could not open XML file: " .. xml_file)
    os.exit(1)
end

local xml_content = xml_file_handle:read("*a")
xml_file_handle:close()

-- Debug: Show XML preview
print("  XML preview: " .. xml_content:sub(1, 100):gsub("\n", " ") .. "...")

-- Parse XML with improved parser
local entity = parseXMLBetter(xml_content)

if not entity.tag then
    print("  ERROR: Failed to parse XML")
    print("  XML content: " .. xml_content)
    os.exit(1)
end

print("  Root tag: " .. entity.tag)
print("  Fields found: " .. #entity.fields)

-- Debug: List all fields found
if next(entity.fields) then
    print("  Field list:")
    for field, value in pairs(entity.fields) do
        -- Truncate long values for display
        local display_value = value
        if #display_value > 50 then
            display_value = display_value:sub(1, 47) .. "..."
        end
        print("    - " .. field .. ": " .. display_value)
    end
else
    print("  WARNING: No fields parsed from XML")
end

-- Use ID from XML if available
local final_id = entity.attrs.id or entity_id or "unknown"
local final_entity_name = entity.tag or entity_name or "unknown"

-- Verify entity name matches expected
if final_entity_name ~= entity_name then
    print("  WARNING: Entity name mismatch. Expected: " .. entity_name .. ", Got: " .. final_entity_name)
    print("  Using: " .. final_entity_name)
end

-- Step 2: Perform substitution (Substitution stage)
local html = template_content

-- First, replace CONST values
print("  Replacing constants...")
local const_count = 0
for const_name, const_value in pairs(constants) do
    local pattern = "__CONST%." .. const_name .. "__"
    local before = html
    html = html:gsub(pattern, const_value)
    if before ~= html then
        const_count = const_count + 1
    end
end
print("  Replaced " .. const_count .. " constants")

-- Then replace entity fields
print("  Replacing entity fields...")
local field_count = 0
for field, value in pairs(entity.fields) do
    local placeholder = "{" .. final_entity_name .. "." .. field .. "}"
    local before = html
    html = html:gsub(placeholder, value)
    if before ~= html then
        field_count = field_count + 1
        print("    - Replaced: " .. field)
    end
end
print("  Replaced " .. field_count .. " fields")

-- Replace entity attributes
print("  Replacing entity attributes...")
local attr_count = 0
for attr, value in pairs(entity.attrs) do
    local placeholder = "{" .. final_entity_name .. "." .. attr .. "}"
    local before = html
    html = html:gsub(placeholder, value)
    if before ~= html then
        attr_count = attr_count + 1
        print("    - Replaced: " .. attr)
    end
end
print("  Replaced " .. attr_count .. " attributes")

-- Step 3: Process Lua fragments
print("  Processing Lua fragments...")
local fragment_start_time = os.clock() * 1000

-- Count fragments before processing
local fragment_count = 0
for _ in html:gmatch("%[lua%]") do
    fragment_count = fragment_count + 1
end

local processed_html = html
local fragment_errors = 0
local fragment_processing_time = 0

if fragment_count > 0 then
    print("    Found " .. fragment_count .. " Lua fragment(s) to process")
    
    -- Process the fragments
    processed_html, processed_fragments, fragment_errors = evalsubst.evaluateLuaFragments(html)
    
    local fragment_end_time = os.clock() * 1000
    fragment_processing_time = fragment_end_time - fragment_start_time
    
    local success_count = fragment_count - fragment_errors
    print("    Processed " .. fragment_count .. " Lua fragment(s): " .. 
          success_count .. " successful, " .. fragment_errors .. " errors")
    print(string.format("    Fragment processing time: %.2f ms", fragment_processing_time))
    
    -- Check for Lua execution errors in the output
    if fragment_errors > 0 then
        print("    WARNING: Some Lua fragments had errors. Check the generated HTML for error markers.")
        -- Show a preview of errors
        local error_locations = 0
        for error_msg in processed_html:gmatch("%[ERROR:[^%]]+%]") do
            if error_locations < 3 then  -- Show first 3 errors
                print("      - " .. error_msg:sub(1, 100) .. (error_msg:len() > 100 and "..." or ""))
            end
            error_locations = error_locations + 1
        end
        if error_locations > 3 then
            print("      ... and " .. (error_locations - 3) .. " more errors")
        end
    end
else
    print("    No Lua fragments found in the template")
end

-- Step 4: Write HTML file (Writer stage)
os.execute("mkdir -p ./output 2>/dev/null")
local output_filename = "./output/" .. final_entity_name .. "-" .. final_id .. ".html"
local output_file = io.open(output_filename, "w")

if output_file then
    output_file:write(processed_html)
    output_file:close()

    local end_time = os.clock() * 1000
    local total_processing_time = end_time - start_time
    local substitution_stage_time = total_processing_time - fragment_processing_time

    -- Build detailed status message
    local status_parts = {}
    table.insert(status_parts, string.format("(%.2f ms total", total_processing_time))
    table.insert(status_parts, string.format("subst: %.2f ms", substitution_stage_time))
    
    if fragment_count > 0 then
        table.insert(status_parts, string.format("lua: %.2f ms", fragment_processing_time))
        table.insert(status_parts, string.format("%d frags", fragment_count))
        if fragment_errors > 0 then
            table.insert(status_parts, string.format("%d errs", fragment_errors))
        end
    end
    
    local status_msg = table.concat(status_parts, ", ") .. ")"
    
    print("  ✓ Written: " .. output_filename .. " " .. status_msg)
    print("  Summary: " .. const_count .. " constants, " .. field_count .. " fields, " .. 
          attr_count .. " attributes" .. 
          (fragment_count > 0 and ", " .. fragment_count .. " Lua fragments" .. 
           (fragment_errors > 0 and " (" .. fragment_errors .. " errors)" or "") or ""))
    
    -- Log summary for pipeline coordination
    local summary_file = io.open("/tmp/luassg_process_summary.log", "a")
    if summary_file then
        summary_file:write(final_entity_name .. "-" .. final_id .. 
                          "|" .. const_count .. 
                          "|" .. field_count .. 
                          "|" .. attr_count .. 
                          "|" .. fragment_count .. 
                          "|" .. fragment_errors .. 
                          "|" .. string.format("%.2f", total_processing_time) .. 
                          "|" .. string.format("%.2f", fragment_processing_time) .. "\n")
        summary_file:close()
    end
    
    return true
else
    print("  ✗ ERROR: Could not write file: " .. output_filename)
    return false
end 