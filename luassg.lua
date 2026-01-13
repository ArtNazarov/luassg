function authorInfo()
    print("About app:")
    print("Static site generator on Lua")
    print("Author: Nazarov A.A., Russia, Orenburg, 2026")
end 

function showHelp()
    print("luassg - Static Site Generator")
    print("===============================")
    print("Usage: lua luassg.lua [OPTION]")
    print()
    print("Options:")
    print("  -h, --help     Show this help message")
    print("  -v, --version  Show version and author information")
    print()
    print("Description:")
    print("  Generates static HTML pages from templates and XML data files.")
    print("  Templates are stored in ./templates/ directory as .html files.")
    print("  Data files are stored in ./data/[entity]/ directory as .xml files.")
    print("  Constants can be defined in ./data/CONST.xml file.")
    print("  Supports dynamic Lua code fragments in templates: [lua]code[/lua]")
    print()
    print("Example:")
    print("  lua luassg.lua           # Generate the site")
    print("  lua luassg.lua --help    # Show this help")
    print("  lua luassg.lua --version # Show version info")
    print()
    authorInfo()
end

function showVersion()
    print("luassg - Static Site Generator v1.1")
    print("=====================================")
    print("Added support for Lua code fragments in templates")
    authorInfo()
end

-- Load Lua evaluation module
local evalsubst = require("lua_evalsubst")

-- Check for command line arguments
local args = {...}
if #args > 0 then
    local arg = args[1]
    if arg == "-h" or arg == "--help" then
        showHelp()
        return
    elseif arg == "-v" or arg == "--version" then
        showVersion()
        return
    else
        print("Unknown option: " .. arg)
        print("Try 'lua luassg.lua --help' for more information.")
        return
    end
end

function dump(o, indent)
    indent = indent or 0
    local spacing = string.rep("  ", indent)
    if type(o) == "table" then
        local s = "{\n"
        for k, v in pairs(o) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. spacing .. "  [" .. k .. "] = " .. dump(v, indent + 1) .. ",\n"
        end
        return s .. spacing .. "}"
    else
        return tostring(o)
    end
end

-- Get current time in milliseconds
local function getTimeMs()
    return os.clock() * 1000
end

-- Synchronous file write function
local function writeFile(filename, content)
    local file = io.open(filename, "w")
    if file then
        file:write(content)
        file:close()
    else
        error("Could not open file: " .. filename)
    end
end

-- Asynchronous file write function
function writeAsync(files)
    local co = {}

    for _, file in ipairs(files) do
        co[#co + 1] = coroutine.create(function()
            writeFile(file.filename, file.content)
        end)
    end

    for _, c in ipairs(co) do
        coroutine.resume(c)
    end
end

function parseConstants()
    local start_time = getTimeMs()
    local const_file = "./data/CONST.xml"
    local f = io.open(const_file, "r")
    if not f then
        return {}
    end
    
    local content = f:read("*a")
    f:close()
    
    local constants = {}
    
    -- First check if it's a CONST root element
    if not content:match("<CONST>") then
        return constants
    end
    
    -- Extract content inside CONST tags
    local const_content = content:match("<CONST>(.-)</CONST>")
    if not const_content then
        return constants
    end
    
    -- Parse all field-value pairs inside CONST
    const_content:gsub(
        "<%s*(%w+)%s*>(.-)</%s*%1%s*>",
        function(field, value)
            value = value:match("^%s*(.-)%s*$")
            constants[field] = value
        end
    )
    
    local end_time = getTimeMs()
    print(string.format("  (Parsed in %.2f ms)", end_time - start_time))
    
    return constants
end

function parseSingleEntity(filename, content)
    local entity = {
        tag = nil,
        fields = {},
        attrs = {}
    }

    local roottag, id = content:match('<(%w+)%s+([^>]*id=[\'"]([^\'"]+)[\'"][^>]*)>')
    if roottag then
        entity.tag = roottag
        if id then
            entity.attrs.id = id
        end
    end

    local root_attrs = content:match("<" .. entity.tag .. "%s+([^>]*)>")
    if root_attrs then
        root_attrs:gsub(
            '(%w+)=[\'"]([^\'"]+)[\'"]',
            function(attr, val)
                entity.attrs[attr] = val
            end
        )
    end

    content:gsub(
        "<%s*(%w+)%s*>(.-)</%s*%1%s*>",
        function(field, value)
            if field ~= entity.tag then
                value = value:match("^%s*(.-)%s*$")
                entity.fields[field] = value
            end
        end
    )
    return entity
end

-- Function to get all entity directories (subfolders in ./data)
local function getEntityDirectories()
    local entities = {}
    local handle = io.popen('ls -d ./data/*/ 2>/dev/null | sed "s|/$||"')
    if handle then
        for dir in handle:lines() do
            local entity_name = dir:match("^./data/(.+)$")
            if entity_name and entity_name ~= "." and entity_name ~= ".." and entity_name ~= "" then
                table.insert(entities, entity_name)
            end
        end
        handle:close()
    end
    return entities
end

-- Function to read all templates
local function readTemplates()
    local templates = {}
    local template_count = 0
    local start_time = getTimeMs()
    local handle = io.popen('find "./templates" -name "*.html" 2>/dev/null')
    if handle then
        for filepath in handle:lines() do
            local file = io.open(filepath, "r")
            if file then
                local template_name = filepath:match("^./templates/(.+)%.html$")
                if template_name then
                    templates[template_name] = {
                        filename = filepath,
                        content = file:read("*a")
                    }
                    template_count = template_count + 1
                end
                file:close()
            end
        end
        handle:close()
    end
    local end_time = getTimeMs()
    print(string.format("  (Read in %.2f ms)", end_time - start_time))
    return templates, template_count
end

-- Function to read all XML files in a directory
local function readAllXMLFiles(dir_path)
    local files = {}
    local start_time = getTimeMs()
    local handle = io.popen('find "' .. dir_path .. '" -name "*.xml" 2>/dev/null')
    if handle then
        for filepath in handle:lines() do
            local file = io.open(filepath, "r")
            if file then
                table.insert(files, {
                    filename = filepath,
                    content = file:read("*a")
                })
                file:close()
            end
        end
        handle:close()
    end
    local end_time = getTimeMs()
    return files, end_time - start_time
end

-- Function to process a single entity type
local function processEntityType(entity_name, template, constants)
    local filesToWrite = {}
    local total_processing_time = 0
    local file_count = 0
    local total_fragments = 0
    local total_errors = 0
    
    print("Processing entity: " .. entity_name)
    
    -- Read all XML files for this entity
    local data_dir = "./data/" .. entity_name
    local data_files, read_time = readAllXMLFiles(data_dir)
    
    print("  Found " .. #data_files .. " data files in " .. data_dir .. string.format(" (read in %.2f ms)", read_time))
    
    -- List all files found
    for _, data_file in ipairs(data_files) do
        print("    - " .. data_file.filename)
    end
    
    -- Process each data file
    for _, data_file in ipairs(data_files) do
        local file_start_time = getTimeMs()
        
        local entity = parseSingleEntity(data_file.filename, data_file.content)
        
        if entity and entity.tag == entity_name then
            -- First replace CONST values
            local html = template.content
            for const_name, const_value in pairs(constants) do
                local pattern = "__CONST%." .. const_name .. "__"
                html = html:gsub(pattern, const_value)
            end
            
            -- Then replace entity fields and attributes
            for field, value in pairs(entity.fields) do
                local placeholder = "{" .. entity.tag .. "." .. field .. "}"
                html = html:gsub(placeholder, value)
            end
            for attr, value in pairs(entity.attrs) do
                local placeholder = "{" .. entity.tag .. "." .. attr .. "}"
                html = html:gsub(placeholder, value)
            end
            
            -- Process Lua fragments in the HTML
            local processed_html, fragment_count, error_count = evalsubst.evaluateLuaFragments(html)
            
            total_fragments = total_fragments + fragment_count
            total_errors = total_errors + error_count
            
            local output_filename = "./output/" .. entity_name .. "-" .. (entity.attrs.id or "unknown") .. ".html"
            
            local file_end_time = getTimeMs()
            local processing_time = file_end_time - file_start_time
            total_processing_time = total_processing_time + processing_time
            file_count = file_count + 1
            
            local fragment_info = ""
            if fragment_count > 0 then
                fragment_info = string.format(", %d Lua fragment(s)", fragment_count)
                if error_count > 0 then
                    fragment_info = fragment_info .. string.format(" (%d error(s))", error_count)
                end
            end
            
            print(string.format("    Generating: %s (%.2f ms%s)", output_filename, processing_time, fragment_info))
            
            table.insert(filesToWrite, {
                filename = output_filename,
                content = processed_html
            })
        else
            local file_end_time = getTimeMs()
            local processing_time = file_end_time - file_start_time
            total_processing_time = total_processing_time + processing_time
            file_count = file_count + 1
            
            if entity then
                print(string.format("    WARNING: Entity tag mismatch. Expected: %s, Got: %s (%.2f ms)", 
                    entity_name, entity.tag or "nil", processing_time))
            else
                print(string.format("    WARNING: Failed to parse entity from: %s (%.2f ms)", 
                    data_file.filename, processing_time))
            end
        end
    end
    
    -- Report Lua fragment statistics for this entity
    if total_fragments > 0 then
        print(string.format("  Lua fragments for %s: %d total, %d errors", entity_name, total_fragments, total_errors))
    end
    
    -- Calculate and display average processing time for this entity
    if file_count > 0 then
        local avg_time = total_processing_time / file_count
        print(string.format("  Average processing time per page for %s: %.2f ms", entity_name, avg_time))
        print(string.format("  Total processing time for %s: %.2f ms", entity_name, total_processing_time))
    end
    
    return filesToWrite, total_processing_time, file_count, total_fragments, total_errors
end

function generateSite()
    print("luassg - Starting site generation...")
    print("=====================================")
    
    local total_start_time = getTimeMs()
    
    os.execute("mkdir -p ./output")
    
    -- Load constants once
    print("Loading constants from ./data/CONST.xml...")
    local constants = parseConstants()
    
    -- Count constants properly
    local const_count = 0
    for _ in pairs(constants) do
        const_count = const_count + 1
    end
    
    print("Loaded " .. const_count .. " constants from ./data/CONST.xml")
    
    -- Read all templates
    print("\nReading templates...")
    local templates, template_count = readTemplates()
    
    -- Get all entity directories
    print("\nScanning entity directories...")
    local entity_dirs = getEntityDirectories()
    
    print("Found " .. #entity_dirs .. " entity directories:")
    for _, entity in ipairs(entity_dirs) do
        print("  - " .. entity)
    end
    
    print("\nFound " .. template_count .. " templates:")
    for template_name, template_data in pairs(templates) do
        print("  - " .. template_name .. " (" .. template_data.filename .. ")")
    end
    
    -- Collect all files to write
    local allFilesToWrite = {}
    local total_processing_time = 0
    local total_pages = 0
    local total_lua_fragments = 0
    local total_lua_errors = 0
    
    -- Process each entity directory
    print("\nProcessing entities...")
    for _, entity_name in ipairs(entity_dirs) do
        -- Check if we have a template for this entity
        local template = templates[entity_name]
        if template then
            print("\nProcessing " .. entity_name .. " with template: " .. template.filename)
            
            -- Process this entity type
            local entityFiles, entity_time, entity_pages, entity_fragments, entity_errors = 
                processEntityType(entity_name, template, constants)
            
            -- Add to the main list
            for _, file in ipairs(entityFiles) do
                table.insert(allFilesToWrite, file)
            end
            
            total_processing_time = total_processing_time + entity_time
            total_pages = total_pages + entity_pages
            total_lua_fragments = total_lua_fragments + entity_fragments
            total_lua_errors = total_lua_errors + entity_errors
        else
            print("\nWARNING: No template found for entity: " .. entity_name)
        end
    end
    
    -- Calculate overall statistics
    local total_end_time = getTimeMs()
    local total_generation_time = total_end_time - total_start_time
    
    print("\n" .. string.rep("=", 60))
    print("GENERATION STATISTICS")
    print(string.rep("=", 60))
    
    if total_pages > 0 then
        local avg_processing_time = total_processing_time / total_pages
        local file_write_time = 0
        
        -- Write all files asynchronously and measure time
        if #allFilesToWrite > 0 then
            print("\nWriting " .. #allFilesToWrite .. " files asynchronously...")
            local write_start_time = getTimeMs()
            writeAsync(allFilesToWrite)
            local write_end_time = getTimeMs()
            file_write_time = write_end_time - write_start_time
            print("All files have been written!")
            
            -- List generated files
            print("\nGenerated files:")
            for _, file in ipairs(allFilesToWrite) do
                print("  " .. file.filename)
            end
            
            -- Print statistics
            print("\n" .. string.rep("-", 60))
            print(string.format("Total pages generated: %d", total_pages))
            print(string.format("Total Lua fragments processed: %d", total_lua_fragments))
            if total_lua_errors > 0 then
                print(string.format("Lua fragment errors: %d", total_lua_errors))
            end
            print(string.format("Total processing time: %.2f ms", total_processing_time))
            print(string.format("Average processing time per page: %.2f ms", avg_processing_time))
            print(string.format("File writing time: %.2f ms", file_write_time))
            print(string.format("Total generation time: %.2f ms", total_generation_time))
            print(string.rep("-", 60))
            
            -- Calculate and display performance metrics
            if total_generation_time > 0 then
                local pages_per_second = (total_pages / total_generation_time) * 1000
                print(string.format("Performance: %.2f pages/second", pages_per_second))
            end
        end
    else
        print("No files to generate.")
    end
    
    print(string.rep("=", 60))
    print("\nSite generation completed!")
end

generateSite()