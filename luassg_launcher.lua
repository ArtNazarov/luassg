-- luassg_launcher.lua - Fixed version
function authorInfo()
    print("About app:")
    print("Static site generator on Lua - Pipeline Version")
    print("Author: Nazarov A.A., Russia, Orenburg, 2026")
end

function showHelp()
    print("luassg_launcher - Static Site Generator Launcher")
    print("================================================")
    print("Usage: lua luassg_launcher.lua")
    print()
    print("Description:")
    print("  Orchestrates the pipeline generation of static HTML pages")
    print("  Launches: scanner → reader → substitution → writer")
    print()
    authorInfo()
end

-- Get current time in milliseconds
local function getTimeMs()
    return os.clock() * 1000
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

-- Function to read all templates
local function readTemplates()
    local templates = {}
    local template_count = 0
    print("Reading templates from ./templates/ ...")
    
    local handle = io.popen('find "./templates" -name "*.html" 2>/dev/null 2>&1')
    if handle then
        for filepath in handle:lines() do
            local file = io.open(filepath, "r")
            if file then
                local template_name = filepath:match("^./templates/(.+)%.html$")
                if template_name then
                    templates[template_name] = file:read("*a")
                    template_count = template_count + 1
                    print("  Loaded template: " .. template_name .. " from " .. filepath)
                end
                file:close()
            end
        end
        handle:close()
    end
    
    if template_count == 0 then
        print("WARNING: No templates found in ./templates/")
    else
        print("Loaded " .. template_count .. " templates")
    end
    
    return templates
end

-- Function to parse constants
local function parseConstants()
    print("Loading constants from ./data/CONST.xml...")
    local const_file = "./data/CONST.xml"
    local f = io.open(const_file, "r")
    if not f then
        print("WARNING: No CONST.xml found, using empty constants")
        return {}
    end
    
    local content = f:read("*a")
    f:close()
    
    local constants = {}
    local const_count = 0
    
    if content:match("<CONST>") then
        local const_content = content:match("<CONST>(.-)</CONST>")
        if const_content then
            const_content:gsub(
                "<%s*(%w+)%s*>(.-)</%s*%1%s*>",
                function(field, value)
                    value = value:match("^%s*(.-)%s*$")
                    constants[field] = value
                    const_count = const_count + 1
                end
            )
        end
    end
    
    if const_count == 0 then
        print("WARNING: No constants found in CONST.xml")
    else
        print("Loaded " .. const_count .. " constants")
    end
    
    return constants
end

-- Simple serialization for pipeline
local function serializeForPipeline(data)
    -- For this simple pipeline, we'll use a file-based approach
    local temp_file = os.tmpname()
    local file = io.open(temp_file, "w")
    
    if file then
        -- Write templates
        file:write("TEMPLATES:\n")
        for name, content in pairs(data.templates) do
            -- Escape newlines for single-line storage
            local escaped_content = content:gsub("\n", "\\n"):gsub("\r", "\\r")
            file:write(name .. "=" .. escaped_content .. "\n")
        end
        
        -- Write constants
        file:write("CONSTANTS:\n")
        for name, value in pairs(data.constants) do
            file:write(name .. "=" .. value .. "\n")
        end
        
        file:write("START_TIME=" .. data.start_time .. "\n")
        file:close()
    end
    
    return temp_file
end

-- Function to launch the pipeline
local function launchPipeline()
    local total_start_time = getTimeMs()
    
    print("luassg_launcher - Starting pipeline generation...")
    print("==================================================")
    
    -- Ensure output directory exists
    os.execute("mkdir -p ./output 2>/dev/null")
    
    -- Load config and templates
    local constants = parseConstants()
    local templates = readTemplates()
    
    -- Check if we have any templates
    local template_count = tableCount(templates)
    
    if template_count == 0 then
        print("\nERROR: No templates found. Cannot generate site.")
        return false
    end
    
    -- Prepare launch data
    local launch_data = {
        constants = constants,
        templates = templates,
        start_time = total_start_time
    }
    
    -- Serialize data to temp file
    local temp_file = serializeForPipeline(launch_data)
    
    print("\nLaunching scanner process...")
    
    -- Launch scanner with the temp file
    local scanner_cmd = string.format('lua luassg_scanner.lua "%s"', temp_file)
    print("Executing: " .. scanner_cmd)
    
    local result = os.execute(scanner_cmd)
    
    -- Clean up temp file
    os.remove(temp_file)
    
    local total_end_time = getTimeMs()
    local total_time = total_end_time - total_start_time
    
    print("\n" .. string.rep("=", 60))
    print("PIPELINE GENERATION COMPLETED")
    print(string.rep("=", 60))
    print(string.format("Total pipeline execution time: %.2f ms", total_time))
    print(string.rep("=", 60))
    
    return result
end

-- Check for command line arguments
local args = {...}
if #args > 0 then
    local arg = args[1]
    if arg == "-h" or arg == "--help" then
        showHelp()
        return
    elseif arg == "-v" or arg == "--version" then
        print("luassg_launcher - Pipeline Version v1.0")
        print("=======================================")
        authorInfo()
        return
    end
end

-- Start the pipeline
local success = launchPipeline()

if not success then
    print("\nERROR: Pipeline execution failed!")
    print("Check that all required files exist:")
    print("  - ./templates/ directory with .html files")
    print("  - ./data/ directory with entity subdirectories")
    print("  - All Lua pipeline files in current directory")
end