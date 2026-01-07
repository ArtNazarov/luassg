-- luassg_scanner.lua - Fixed version without table.getn
print("luassg_scanner - Scanning data directories...")
print("=============================================")

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

-- Get temp file from command line
local args = {...}
local temp_file = args[1]

if not temp_file or temp_file == "" then
    print("ERROR: No data file provided")
    os.exit(1)
end

-- Read launch data from temp file
local file = io.open(temp_file, "r")
if not file then
    print("ERROR: Could not open data file: " .. temp_file)
    os.exit(1)
end

local launch_data = {
    templates = {},
    constants = {},
    start_time = nil
}

local section = nil
for line in file:lines() do
    if line == "TEMPLATES:" then
        section = "templates"
    elseif line == "CONSTANTS:" then
        section = "constants"
    elseif line:match("START_TIME=") then
        launch_data.start_time = tonumber(line:match("START_TIME=(.+)"))
    else
        local k, v = line:match("([^=]+)=(.+)")
        if k and v and section then
            if section == "templates" then
                -- Unescape newlines in template content
                v = v:gsub("\\n", "\n"):gsub("\\r", "\r")
                launch_data.templates[k] = v
            elseif section == "constants" then
                launch_data.constants[k] = v
            end
        end
    end
end
file:close()

print("Loaded " .. tableCount(launch_data.templates) .. " templates")
print("Loaded " .. tableCount(launch_data.constants) .. " constants")

-- Find all entity directories
print("\nFinding entity directories in ./data/ ...")

-- Use simple directory listing
local handle = io.popen('ls -d ./data/*/ 2>/dev/null | grep -v "/CONST.xml"')
local entity_count = 0

if handle then
    for dir in handle:lines() do
        local entity_name = dir:match("^./data/(.+)/$")
        if entity_name and entity_name ~= "." and entity_name ~= ".." then
            entity_count = entity_count + 1
            
            -- Check if we have a matching template
            local template_content = launch_data.templates[entity_name]
            
            if template_content then
                print("\nProcessing entity: " .. entity_name)
                
                -- Find XML files in this directory
                local xml_handle = io.popen('find "./data/' .. entity_name .. '" -name "*.xml" 2>/dev/null')
                local xml_count = 0
                
                if xml_handle then
                    for xml_file in xml_handle:lines() do
                        xml_count = xml_count + 1
                        
                        -- Extract entity ID from filename
                        local filename = xml_file:match("^.*/([^/]+)%.xml$")
                        local entity_id = filename:gsub(entity_name .. "%-", ""):gsub("%.xml$", "")
                        
                        print("  Found: " .. filename .. " -> ID: " .. entity_id)
                        
                        -- Prepare data for reader
                        local reader_data = {
                            entity_name = entity_name,
                            entity_id = entity_id,
                            xml_file = xml_file,
                            template = template_content,
                            constants = launch_data.constants,
                            start_time = launch_data.start_time
                        }
                        
                        -- Serialize and save to temp file
                        local reader_temp = os.tmpname()
                        local reader_file = io.open(reader_temp, "w")
                        
                        if reader_file then
                            -- Simple serialization
                            reader_file:write("ENTITY_NAME=" .. entity_name .. "\n")
                            reader_file:write("ENTITY_ID=" .. entity_id .. "\n")
                            reader_file:write("XML_FILE=" .. xml_file .. "\n")
                            reader_file:write("TEMPLATE=" .. template_content:gsub("\n", "\\n"):gsub("\r", "\\r") .. "\n")
                            reader_file:write("START_TIME=" .. (launch_data.start_time or os.clock() * 1000) .. "\n")
                            
                            -- Write constants
                            reader_file:write("CONSTANTS_BEGIN\n")
                            for const_name, const_value in pairs(launch_data.constants) do
                                reader_file:write(const_name .. "=" .. const_value .. "\n")
                            end
                            reader_file:write("CONSTANTS_END\n")
                            
                            reader_file:close()
                            
                            -- Launch reader
                            local reader_cmd = string.format('lua luassg_reader.lua "%s"', reader_temp)
                            os.execute(reader_cmd)
                            
                            -- Clean up temp file
                            os.remove(reader_temp)
                        end
                    end
                    xml_handle:close()
                    
                    if xml_count == 0 then
                        print("  No XML files found in " .. entity_name)
                    else
                        print("  Processed " .. xml_count .. " XML files")
                    end
                end
            else
                print("\nWARNING: No template found for entity: " .. entity_name)
            end
        end
    end
    handle:close()
end

if entity_count == 0 then
    print("No entity directories found in ./data/")
else
    print("\nScanned " .. entity_count .. " entity directories")
end