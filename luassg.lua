function authorInfo()
    print("About app:")
    print("Static site generator on Lua")
    print("Author: Nazarov A.A., Russia, Orenburg, 2026")
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

function parseConstants()
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
    
    return constants
end

function replaceConstants(template, constants)
    local html = template
    
    -- Replace all occurrences of __CONST.VALUENAME__
    for const_name, const_value in pairs(constants) do
        local pattern = "__CONST%." .. const_name .. "__"
        html = html:gsub(pattern, const_value)
    end
    
    return html
end

function parseSingleEntity(filename)
    local f = io.open(filename, "r")
    if not f then
        return nil
    end
    local content = f:read("*a")
    f:close()
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

function render(template, entity, constants)
    -- First replace CONST values
    local html = replaceConstants(template, constants)
    
    -- Then replace entity fields and attributes
    for field, value in pairs(entity.fields) do
        local placeholder = "{" .. entity.tag .. "." .. field .. "}"
        html = html:gsub(placeholder, value)
    end
    for attr, value in pairs(entity.attrs) do
        local placeholder = "{" .. entity.tag .. "." .. attr .. "}"
        html = html:gsub(placeholder, value)
    end
    return html
end

function scandir(directory)
    local t = {}
    local pfile = io.popen("ls -1 " .. directory .. " 2>/dev/null")
    if pfile then
        for filename in pfile:lines() do
            if filename:match("%.xml$") then
                table.insert(t, filename)
            end
        end
        pfile:close()
    end
    return t
end

function generateSite()
    os.execute("mkdir -p ./output")
    
    -- Load constants once
    local constants = parseConstants()
    
    -- Count constants properly
    local const_count = 0
    for _ in pairs(constants) do
        const_count = const_count + 1
    end
    
    print("Loaded " .. const_count .. " constants from ./data/CONST.xml")
    
    for template_file in io.popen("ls -- ./templates"):lines() do
        local template_path = "./templates/" .. template_file
        print("Processing template " .. template_path)
        local template_f = io.open(template_path, "r")
        if not template_f then
            goto continue
        end
        local template = template_f:read("*a")
        template_f:close()

        local entity_type = template_file:gsub("%.html$", "")
        local data_dir = "./data/" .. entity_type

        os.execute("mkdir -p " .. data_dir)

        local files = scandir(data_dir)
        for _, data_file in ipairs(files) do
            local entity_path = data_dir .. "/" .. data_file
            local entity = parseSingleEntity(entity_path)
            if entity and entity.tag == entity_type then
                local output_filename = "./output/" .. entity_type .. "-" .. (entity.attrs.id or "unknown") .. ".html"
                local output = io.open(output_filename, "w")
                output:write(render(template, entity, constants))
                output:close()
                print("Generated: " .. output_filename)
            end
        end
        ::continue::
    end
end

generateSite()