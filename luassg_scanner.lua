-- luassg_scanner.lua - Parallel processing with proper cleanup
print("luassg_scanner - Parallel processing version")
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

-- Save constants to a temp file for sharing
local constants_temp = os.tmpname()
local constants_file = io.open(constants_temp, "w")
if constants_file then
    for const_name, const_value in pairs(launch_data.constants) do
        constants_file:write(const_name .. "=" .. const_value .. "\n")
    end
    constants_file:close()
end

-- Find all XML files across all entities
print("\nScanning for XML files across all entities...")
local all_jobs = {}

local handle = io.popen('find ./data -name "*.xml" ! -name "CONST.xml" 2>/dev/null')
if handle then
    for xml_file in handle:lines() do
        -- Extract entity name from path
        local entity_name = xml_file:match("^./data/([^/]+)/")
        if entity_name and launch_data.templates[entity_name] then
            local filename = xml_file:match("^.*/([^/]+)%.xml$")
            local entity_id = filename:gsub(entity_name .. "%-", ""):gsub("%.xml$", "")
            
            table.insert(all_jobs, {
                entity_name = entity_name,
                entity_id = entity_id,
                xml_file = xml_file,
                template = launch_data.templates[entity_name],
                start_time = launch_data.start_time
            })
            
            print("  Found: " .. filename .. " -> " .. entity_name .. "-" .. entity_id)
        elseif entity_name and not launch_data.templates[entity_name] then
            print("  WARNING: No template for entity: " .. entity_name .. " (file: " .. xml_file .. ")")
        end
    end
    handle:close()
end

print("\nFound " .. #all_jobs .. " XML files to process")

-- Process in parallel batches
local BATCH_SIZE = 2  -- Process 2 files at a time
local completed = 0
local total_files = #all_jobs

if total_files == 0 then
    print("No XML files to process!")
    os.remove(constants_temp)
    return
end

-- Calculate number of batches
local num_batches = math.ceil(total_files / BATCH_SIZE)
print("Processing in " .. num_batches .. " batches (batch size: " .. BATCH_SIZE .. ")")

-- Store all process PIDs
local all_pids = {}

for batch_num = 1, num_batches do
    local batch_start = (batch_num - 1) * BATCH_SIZE + 1
    local batch_end = math.min(batch_num * BATCH_SIZE, total_files)
    
    print("\n--- Processing Batch " .. batch_num .. "/" .. num_batches .. 
          " (files " .. batch_start .. "-" .. batch_end .. ") ---")
    
    for i = batch_start, batch_end do
        local job = all_jobs[i]
        print("  Launching: " .. job.entity_name .. "-" .. job.entity_id)
        
        -- Escape template content for command line
        local escaped_template = job.template:gsub('"', '\\"'):gsub("'", "\\'")
        
        -- Build command for complete pipeline
        local cmd = string.format(
            'lua luassg_process_file.lua "%s" "%s" "%s" "%s" "%s" "%s" > /tmp/luassg_%s_%s.log 2>&1 & echo $!',
            job.entity_name,
            job.entity_id,
            job.xml_file,
            escaped_template,
            job.start_time,
            constants_temp,
            job.entity_name,
            job.entity_id
        )
        
        -- Launch in background and capture PID
        local pid_handle = io.popen(cmd)
        if pid_handle then
            local pid = pid_handle:read("*a")
            pid = pid:match("%d+")
            if pid then
                table.insert(all_pids, pid)
                print("    PID: " .. pid)
            end
            pid_handle:close()
        end
    end
end

-- Wait for ALL processes to complete
print("\n" .. string.rep("-", 60))
print("Waiting for ALL background processes to complete...")

local max_wait_time = 10  -- Maximum wait time in seconds
local start_wait = os.time()
local processes_remaining = #all_pids

while processes_remaining > 0 and (os.time() - start_wait) < max_wait_time do
    local completed_now = 0
    
    for i = #all_pids, 1, -1 do
        local pid = all_pids[i]
        -- Check if process is still running
        local check_cmd = string.format('kill -0 %s 2>/dev/null && echo "running"', pid)
        local check_handle = io.popen(check_cmd)
        if check_handle then
            local status = check_handle:read("*a")
            check_handle:close()
            
            if status == "" then
                -- Process has finished
                table.remove(all_pids, i)
                completed_now = completed_now + 1
            end
        end
    end
    
    if completed_now > 0 then
        print("  " .. completed_now .. " processes completed")
    end
    
    processes_remaining = #all_pids
    
    if processes_remaining > 0 then
        -- Small delay before checking again
        os.execute("sleep 0.1")
    end
end

-- Final check and cleanup
if #all_pids > 0 then
    print("\nWARNING: " .. #all_pids .. " processes still running after timeout")
    print("Killing remaining processes...")
    for _, pid in ipairs(all_pids) do
        os.execute("kill " .. pid .. " 2>/dev/null")
    end
else
    print("\n✓ All processes completed successfully")
end

-- Clean up constants temp file
os.remove(constants_temp)

-- Show generated files
print("\n" .. string.rep("=", 60))
print("PARALLEL PROCESSING COMPLETED!")
print(string.rep("=", 60))
print("Total files processed: " .. total_files)
print("Batch size used: " .. BATCH_SIZE)
print("Number of batches: " .. num_batches)

-- List generated files
print("\nGenerated HTML files:")
local output_handle = io.popen('ls -1 ./output/*.html 2>/dev/null | wc -l')
if output_handle then
    local file_count = output_handle:read("*a")
    file_count = tonumber(file_count) or 0
    output_handle:close()
    
    if file_count > 0 then
        local list_handle = io.popen('ls ./output/*.html 2>/dev/null')
        if list_handle then
            for file in list_handle:lines() do
                print("  " .. file)
            end
            list_handle:close()
        end
        print("Total generated: " .. file_count .. " files")
    else
        print("  No files generated in ./output/")
    end
end

print(string.rep("=", 60))