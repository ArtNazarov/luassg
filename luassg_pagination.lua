-- luassg_pagination.lua - Pagination and sitemap generator for luassg
print("luassg_pagination - Generating paginated lists and sitemap...")
print("=============================================================")

-- Helper function to get current time in milliseconds
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

-- Function to read and parse XML content
local function parseXML(content)
    local data = {}

    -- Parse pagination settings
    if content:match("<pagination>") then
        local pagination_content = content:match("<pagination>(.-)</pagination>")
        if pagination_content then
            -- Extract basic settings
            data.generatedHeadingPattern = pagination_content:match("<generatedHeadingPattern>(.-)</generatedHeadingPattern>") or "Category: {categoryTitle} - {page}/{totalPages}"
            data.listPathPattern = pagination_content:match("<listPathPattern>(.-)</listPathPattern>") or "section-{category}{page}.html"
            data.fieldAsTitle = pagination_content:match("<fieldAsTitle>(.-)</fieldAsTitle>")
            data.fieldAsCategory = pagination_content:match("<fieldAsCategory>(.-)</fieldAsCategory>")
            data.templateList = pagination_content:match("<templateList>(.-)</templateList>") or "./templates/pagination/categoryTemplate.html"
            data.itemsPerPage = tonumber(pagination_content:match("<itemsPerPage>(.-)</itemsPerPage>")) or 10

            -- Parse index page category
            if pagination_content:match("<indexPageCategory>") then
                local index_content = pagination_content:match("<indexPageCategory>(.-)</indexPageCategory>")
                if index_content then
                    data.useCategory = index_content:match("<useCategory>(.-)</useCategory>")
                end
            end

            -- Parse categories to include
            data.includeCategories = {}
            if pagination_content:match("<createPagingFor>") then
                local paging_content = pagination_content:match("<createPagingFor>(.-)</createPagingFor>")
                if paging_content then
                    for category in paging_content:gmatch("<includeCategory>(.-)</includeCategory>") do
                        table.insert(data.includeCategories, category)
                    end
                end
            end

            -- Parse sitemap settings
            if pagination_content:match("<sitemap>") then
                local sitemap_content = pagination_content:match("<sitemap>(.-)</sitemap>")
                if sitemap_content then
                    data.sitemap = {}
                    data.sitemap.mapFileName = sitemap_content:match("<mapFileName>(.-)</mapFileName>") or "./sitemap.xml"
                    data.sitemap.mapGeneratedPattern = sitemap_content:match("<mapGeneratedPattern>(.-)</mapGeneratedPattern>") or "Sitemap {totalPagesCount}"
                    data.sitemap.mapTemplate = sitemap_content:match("<mapTemplate>(.-)</mapTemplate>") or "./templates/pagination/sitemapTemplate.html"
                    data.sitemap.mapSaveAs = sitemap_content:match("<mapSaveAs>(.-)</mapSaveAs>") or "./output/sitemap.html"
                    data.sitemap.mapItemsPerPage = tonumber(sitemap_content:match("<mapItemsPerPage>(.-)</mapItemsPerPage>")) or 50
                end
            end
        end
    end

    return data
end

-- Function to load constants
local function loadConstants()
    local constants = {}
    local const_file = "./data/CONST.xml"
    local f = io.open(const_file, "r")

    if f then
        local content = f:read("*a")
        f:close()

        if content:match("<CONST>") then
            local const_content = content:match("<CONST>(.-)</CONST>")
            if const_content then
                const_content:gsub(
                    "<%s*(%w+)%s*>(.-)</%s*%1%s*>",
                    function(field, value)
                        value = value:match("^%s*(.-)%s*$")
                        constants[field] = value
                    end
                )
            end
        end
    end

    return constants
end

-- Function to check if template exists
local function checkTemplate(templatePath)
    local file = io.open(templatePath, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- Function to find template in alternative locations
local function findTemplate(templateName)
    -- Try the specified path first
    if checkTemplate(templateName) then
        return templateName
    end

    -- Try relative path from current directory
    if checkTemplate("./" .. templateName) then
        return "./" .. templateName
    end

    -- Try in templates directory
    local altPath = "./templates/" .. templateName:match("[^/]+$")
    if checkTemplate(altPath) then
        return altPath
    end

    -- Try in pagination templates directory
    local paginationAltPath = "./templates/pagination/" .. templateName:match("[^/]+$")
    if checkTemplate(paginationAltPath) then
        return paginationAltPath
    end

    return nil
end

-- Function to parse a single XML entity (copied from luassg.lua with modifications)
local function parseSingleEntity(filename, content)
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

-- Function to read all XML files for an entity (similar to luassg.lua)
local function readAllXMLFilesForEntity(entity_name)
    local files = {}
    local data_dir = "./data/" .. entity_name
    local start_time = getTimeMs()
    
    local handle = io.popen('find "' .. data_dir .. '" -name "*.xml" 2>/dev/null')
    if handle then
        for filepath in handle:lines() do
            local file = io.open(filepath, "r")
            if file then
                local content = file:read("*a")
                file:close()
                
                table.insert(files, {
                    filename = filepath,
                    content = content
                })
            end
        end
        handle:close()
    end
    
    local end_time = getTimeMs()
    return files, end_time - start_time
end

-- Function to get all entity directories (similar to luassg.lua)
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

-- Function to collect all entities data directly from XML files
local function collectAllEntitiesData()
    local allEntities = {}
    local entity_dirs = getEntityDirectories()
    
    for _, entity_name in ipairs(entity_dirs) do
        local xml_files, read_time = readAllXMLFilesForEntity(entity_name)
        
        for _, xml_file in ipairs(xml_files) do
            local entity = parseSingleEntity(xml_file.filename, xml_file.content)
            
            if entity and entity.tag == entity_name then
                -- Create a unique key for this entity
                local key = entity_name .. "-" .. (entity.attrs.id or "unknown")
                
                allEntities[key] = {
                    entity_name = entity_name,
                    entity_id = entity.attrs.id or "unknown",
                    fields = entity.fields,
                    attrs = entity.attrs,
                    filename = entity_name .. "-" .. (entity.attrs.id or "unknown") .. ".html",
                    title = entity.fields.name or entity.fields.title or 
                           entity.fields.Name or entity.fields.Title or 
                           (entity_name .. "-" .. (entity.attrs.id or "unknown"))
                }
            end
        end
    end
    
    return allEntities
end

-- Function to group entities by category from XML data
local function groupEntitiesByCategory(allEntities, fieldAsCategory)
    local categories = {}
    
    for _, entity_data in pairs(allEntities) do
        local category = nil
        
        -- Get category from fieldAsCategory
        if fieldAsCategory and entity_data.fields[fieldAsCategory] then
            category = entity_data.fields[fieldAsCategory]
        elseif fieldAsCategory and entity_data.attrs[fieldAsCategory] then
            category = entity_data.attrs[fieldAsCategory]
        else
            category = "uncategorized"
        end
        
        if not categories[category] then
            categories[category] = {
                title = category,
                entities = {}
            }
        end
        
        table.insert(categories[category].entities, {
            filename = entity_data.filename,
            title = entity_data.title,
            entity_name = entity_data.entity_name,
            entity_id = entity_data.entity_id
        })
    end
    
    return categories
end

-- Function to generate pagination links
local function generatePagination(currentPage, totalPages, category, listPathPattern)
    local pagination = {}

    if totalPages <= 1 then
        return ""
    end

    -- Always show first page
    local path1 = listPathPattern:gsub("{category}", category):gsub("{page}", "1")
    table.insert(pagination, '<a href="' .. path1 .. '">1</a>')

    -- Calculate range around current page
    local startPage = math.max(2, currentPage - 2)
    local endPage = math.min(totalPages - 1, currentPage + 2)

    -- Add ellipsis if needed
    if startPage > 2 then
        table.insert(pagination, '<span>...</span>')
    end

    -- Add middle pages
    for page = startPage, endPage do
        local path = listPathPattern:gsub("{category}", category):gsub("{page}", tostring(page))
        if page == currentPage then
            table.insert(pagination, '<strong>' .. page .. '</strong>')
        else
            table.insert(pagination, '<a href="' .. path .. '">' .. page .. '</a>')
        end
    end

    -- Add ellipsis if needed
    if endPage < totalPages - 1 then
        table.insert(pagination, '<span>...</span>')
    end

    -- Always show last page if there is more than one page
    if totalPages > 1 then
        local pathLast = listPathPattern:gsub("{category}", category):gsub("{page}", tostring(totalPages))
        table.insert(pagination, '<a href="' .. pathLast .. '">' .. totalPages .. '</a>')
    end

    return '<div class="pagination">' .. table.concat(pagination, " ") .. '</div>'
end

-- Function to load and process template
local function processTemplate(templateFile, replacements, constants)
    -- Try to find the template
    local actualTemplateFile = findTemplate(templateFile)

    if not actualTemplateFile then
        error("Could not find template file: " .. templateFile .. "\n" ..
              "Tried: " .. templateFile .. ", ./" .. templateFile .. ", " ..
              "./templates/" .. templateFile:match("[^/]+$") .. ", " ..
              "./templates/pagination/" .. templateFile:match("[^/]+$"))
    end

    local file = io.open(actualTemplateFile, "r")
    if not file then
        error("Could not open template file: " .. actualTemplateFile)
    end

    local content = file:read("*a")
    file:close()

    -- Apply all replacements
    for placeholder, value in pairs(replacements) do
        content = content:gsub("{" .. placeholder .. "}", value)
    end
    
    -- Replace constants
    for constName, constValue in pairs(constants) do
        content = content:gsub("__CONST%." .. constName .. "__", constValue)
    end

    return content
end

-- Function to generate category pages
local function generateCategoryPages(categories, settings, constants)
    local generatedPages = {}
    local totalCategoryPages = 0

    -- Ensure output directory exists
    os.execute("mkdir -p ./output 2>/dev/null")

    for category, data in pairs(categories) do
        -- Skip categories not in include list if specified
        if #settings.includeCategories > 0 then
            local include = false
            for _, incCat in ipairs(settings.includeCategories) do
                if category == incCat then
                    include = true
                    break
                end
            end
            if not include then
                print("  Skipping category (not in include list): " .. category)
                goto continue
            end
        end

        print("  Processing category: " .. category .. " (" .. #data.entities .. " entities)")

        -- Calculate number of pages
        local itemsPerPage = settings.itemsPerPage
        local totalPages = math.ceil(#data.entities / itemsPerPage)

        -- Generate pages for this category
        for page = 1, totalPages do
            local startIndex = (page - 1) * itemsPerPage + 1
            local endIndex = math.min(page * itemsPerPage, #data.entities)

            -- Generate list of items for this page
            local listItems = {}
            for i = startIndex, endIndex do
                local entity = data.entities[i]
                table.insert(listItems, '<li><a href="' .. entity.filename .. '">' .. entity.title .. '</a></li>')
            end

            local listHTML = '<ul class="category-list">' .. table.concat(listItems, "\n") .. '</ul>'

            -- Generate pagination links
            local paginationHTML = generatePagination(page, totalPages, category, settings.listPathPattern)

            -- Generate heading
            local heading = settings.generatedHeadingPattern
                :gsub("{categoryTitle}", data.title)
                :gsub("{page}", tostring(page))
                :gsub("{totalPages}", tostring(totalPages))
                :gsub("{category}", category)

            -- Check and load template
            local templatePath = findTemplate(settings.templateList)
            if not templatePath then
                print("    ERROR: Template not found: " .. settings.templateList)
                goto continue_page
            end

            -- Process template
            local replacements = {
                generatedHeading = heading,
                list = listHTML,
                pagination = paginationHTML
            }

            local content
            local success, err = pcall(function()
                content = processTemplate(settings.templateList, replacements, constants)
            end)

            if not success then
                print("    ERROR: " .. err)
                goto continue_page
            end

            -- Generate output filename
            local outputFilename = settings.listPathPattern
                :gsub("{category}", category)
                :gsub("{page}", tostring(page))

            -- Ensure .html extension
            if not outputFilename:match("%.html$") then
                outputFilename = outputFilename .. ".html"
            end

            local outputPath = "./output/" .. outputFilename

            -- Write file
            local outputFile = io.open(outputPath, "w")
            if outputFile then
                outputFile:write(content)
                outputFile:close()

                -- Add to generated pages list
                table.insert(generatedPages, {
                    path = outputPath,
                    filename = outputFilename,
                    title = heading,
                    category = category,
                    page = page,
                    totalPages = totalPages
                })

                totalCategoryPages = totalCategoryPages + 1
                print("    Generated: " .. outputFilename .. " using " .. templatePath)
            else
                print("    ERROR: Could not write file: " .. outputPath)
            end

            ::continue_page::
        end

        ::continue::
    end

    return generatedPages, totalCategoryPages
end

-- Function to generate XML sitemap (now defined locally)
local function generateXMLSitemap(pages, outputPath)
    local xml = '<?xml version="1.0" encoding="UTF-8"?>\n'
    xml = xml .. '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'

    local baseUrl = "http://example.com/"  -- This should be configurable

    for _, page in ipairs(pages) do
        xml = xml .. '  <url>\n'
        xml = xml .. '    <loc>' .. baseUrl .. page.url .. '</loc>\n'
        xml = xml .. '    <priority>' .. string.format("%.1f", page.priority or 0.5) .. '</priority>\n'
        xml = xml .. '    <changefreq>weekly</changefreq>\n'
        xml = xml .. '  </url>\n'
    end

    xml = xml .. '</urlset>\n'

    local file = io.open(outputPath, "w")
    if file then
        file:write(xml)
        file:close()
        print("  Generated XML sitemap: " .. outputPath)
    end
end

-- Function to generate sitemap
local function generateSitemap(allEntities, categoryPages, settings, constants)
    if not settings.sitemap then
        return
    end

    print("\nGenerating sitemap...")

    -- Combine all pages
    local allPagesCombined = {}

    -- Add category pages first
    for _, page in ipairs(categoryPages) do
        table.insert(allPagesCombined, {
            url = page.filename,
            title = page.title,
            priority = 0.8
        })
    end

    -- Add entity pages
    for _, entity_data in pairs(allEntities) do
        table.insert(allPagesCombined, {
            url = entity_data.filename,
            title = entity_data.title,
            priority = 1.0
        })
    end

    -- Calculate total pages count (excluding category pages)
    local totalPagesCount = tableCount(allEntities)

    -- Generate sitemap heading
    local heading = settings.sitemap.mapGeneratedPattern:gsub("{totalPagesCount}", tostring(totalPagesCount))

    -- Generate list items
    local listItems = {}
    for _, page in ipairs(allPagesCombined) do
        table.insert(listItems, '<li><a href="' .. page.url .. '">' .. page.title .. '</a></li>')
    end

    local listHTML = '<ul class="sitemap-list">' .. table.concat(listItems, "\n") .. '</ul>'

    -- Check and load sitemap template
    local templatePath = findTemplate(settings.sitemap.mapTemplate)

    if not templatePath then
        print("  WARNING: Sitemap template not found: " .. settings.sitemap.mapTemplate)
        return
    end

    -- Process template with replacements
    local replacements = {
        generatedHeading = heading,
        list = listHTML,
        pagination = ""  -- Sitemap doesn't need pagination
    }

    local content
    local success, err = pcall(function()
        content = processTemplate(settings.sitemap.mapTemplate, replacements, constants)
    end)

    if not success then
        print("  ERROR: " .. err)
        return
    end

    -- Write sitemap file to output directory
    local outputPath = settings.sitemap.mapSaveAs
    if not outputPath:match("^./output/") then
        outputPath = "./output/" .. outputPath:match("([^/]+)$")
    end
    
    local outputFile = io.open(outputPath, "w")

    if outputFile then
        outputFile:write(content)
        outputFile:close()
        print("  Generated sitemap: " .. outputPath .. " using " .. templatePath)

        -- Also generate XML sitemap for search engines
        generateXMLSitemap(allPagesCombined, settings.sitemap.mapFileName)
    else
        print("  ERROR: Could not write sitemap: " .. outputPath)
    end
end

-- Function to generate index page (FIXED: handle excluded categories)
local function generateIndexPage(categories, settings, constants, categoryPages)
    if not settings.useCategory then
        return
    end

    print("\nGenerating index page...")

    -- Find the specified category
    local indexCategory = nil
    for category, data in pairs(categories) do
        if category == settings.useCategory then
            indexCategory = data
            break
        end
    end

    if not indexCategory then
        print("  WARNING: Index category not found: " .. settings.useCategory)
        return
    end

    -- Check if this category is in the include list
    local isIncluded = false
    for _, incCat in ipairs(settings.includeCategories) do
        if settings.useCategory == incCat then
            isIncluded = true
            break
        end
    end

    -- If the index category is not in the include list, we need to generate it manually
    if not isIncluded then
        print("  Index category '" .. settings.useCategory .. "' is not in include list, generating it separately...")
        
        -- Calculate number of pages
        local itemsPerPage = settings.itemsPerPage
        local totalPages = math.ceil(#indexCategory.entities / itemsPerPage)
        
        -- Always use page 1 for index
        local page = 1
        local startIndex = (page - 1) * itemsPerPage + 1
        local endIndex = math.min(page * itemsPerPage, #indexCategory.entities)

        -- Generate list of items for this page
        local listItems = {}
        for i = startIndex, endIndex do
            local entity = indexCategory.entities[i]
            table.insert(listItems, '<li><a href="' .. entity.filename .. '">' .. entity.title .. '</a></li>')
        end

        local listHTML = '<ul class="category-list">' .. table.concat(listItems, "\n") .. '</ul>'

        -- Generate pagination links
        local paginationHTML = generatePagination(page, totalPages, settings.useCategory, settings.listPathPattern)

        -- Generate heading
        local heading = settings.generatedHeadingPattern
            :gsub("{categoryTitle}", indexCategory.title)
            :gsub("{page}", tostring(page))
            :gsub("{totalPages}", tostring(totalPages))
            :gsub("{category}", settings.useCategory)

        -- Check and load template
        local templatePath = findTemplate(settings.templateList)
        if not templatePath then
            print("    ERROR: Template not found: " .. settings.templateList)
            return
        end

        -- Process template
        local replacements = {
            generatedHeading = heading,
            list = listHTML,
            pagination = paginationHTML
        }

        local content
        local success, err = pcall(function()
            content = processTemplate(settings.templateList, replacements, constants)
        end)

        if not success then
            print("    ERROR: " .. err)
            return
        end

        -- Create the category page for index
        local indexPath = "./output/index.html"
        local indexFile = io.open(indexPath, "w")
        if indexFile then
            indexFile:write(content)
            indexFile:close()
            print("  Generated index page: " .. indexPath)
        else
            print("  ERROR: Could not write index page: " .. indexPath)
        end
    else
        -- Category is in include list, use the first page as index
        local indexPath = "./output/index.html"
        local sourcePath = "./output/" .. settings.listPathPattern
            :gsub("{category}", settings.useCategory)
            :gsub("{page}", "1")

        if not sourcePath:match("%.html$") then
            sourcePath = sourcePath .. ".html"
        end

        -- Copy the file
        local sourceFile = io.open(sourcePath, "r")
        if sourceFile then
            local content = sourceFile:read("*a")
            sourceFile:close()

            -- Modify title for index page
            content = content:gsub("<title>[^<]+</title>", "<title>" .. (constants.SITENAME or "Site") .. " - Home</title>")

            local indexFile = io.open(indexPath, "w")
            if indexFile then
                indexFile:write(content)
                indexFile:close()
                print("  Generated index page: " .. indexPath .. " (copied from " .. sourcePath .. ")")
            end
        else
            print("  ERROR: Could not find source for index: " .. sourcePath)
        end
    end
end

-- Function to ensure template directories exist
local function ensureTemplateDirectories()
    os.execute("mkdir -p ./templates/pagination 2>/dev/null")
    os.execute("mkdir -p ./output 2>/dev/null")
end

-- Main function
local function main()
    local start_time = getTimeMs()

    -- Ensure template directories exist
    ensureTemplateDirectories()

    -- Check if pagination.xml exists in ./data directory
    local pagination_file = "./data/pagination.xml"
    local f = io.open(pagination_file, "r")

    if not f then
        print("ERROR: pagination.xml not found in ./data/ directory!")
        print("Please create pagination.xml in ./data/ directory with pagination settings.")
        os.exit(1)
    end

    local content = f:read("*a")
    f:close()

    -- Parse pagination settings
    print("Parsing pagination settings from ./data/pagination.xml...")
    local settings = parseXML(content)

    if not settings.fieldAsCategory then
        print("WARNING: fieldAsCategory not specified in pagination.xml")
        print("Will use 'uncategorized' for all files.")
    end

    -- Load constants
    print("Loading constants from ./data/CONST.xml...")
    local constants = loadConstants()
    print("Loaded " .. tableCount(constants) .. " constants")

    -- Check if templates exist
    print("Checking templates...")
    local categoryTemplatePath = findTemplate(settings.templateList)
    if categoryTemplatePath then
        print("  Found category template: " .. categoryTemplatePath)
    else
        print("  WARNING: Category template not found: " .. settings.templateList)
        print("  Will look for default template...")
    end

    if settings.sitemap then
        local sitemapTemplatePath = findTemplate(settings.sitemap.mapTemplate)
        if sitemapTemplatePath then
            print("  Found sitemap template: " .. sitemapTemplatePath)
        else
            print("  WARNING: Sitemap template not found: " .. settings.sitemap.mapTemplate)
        end
    end

    -- Read all entity data directly from XML files
    print("\nCollecting entity data from XML files...")
    local allEntities = collectAllEntitiesData()
    print("Found " .. tableCount(allEntities) .. " entities in XML files")

    -- Group entities by category
    print("Grouping entities by category...")
    local categories = groupEntitiesByCategory(allEntities, settings.fieldAsCategory)
    print("Found " .. tableCount(categories) .. " categories")

    -- Display categories found
    for category, data in pairs(categories) do
        print("  - " .. category .. ": " .. #data.entities .. " entities")
    end

    -- Generate category pages
    print("\nGenerating category pages...")
    local categoryPages, totalCategoryPages = generateCategoryPages(categories, settings, constants)

    -- Generate index page if configured (pass categoryPages as parameter)
    generateIndexPage(categories, settings, constants, categoryPages)

    -- Generate sitemap if configured
    generateSitemap(allEntities, categoryPages, settings, constants)

    local end_time = getTimeMs()
    local total_time = end_time - start_time

    print("\n" .. string.rep("=", 60))
    print("PAGINATION GENERATION COMPLETED")
    print(string.rep("=", 60))
    print(string.format("Total time: %.2f ms", total_time))
    print(string.format("Total entities processed: %d", tableCount(allEntities)))
    print(string.format("Total categories: %d", tableCount(categories)))
    print(string.format("Total category pages generated: %d", totalCategoryPages))

    -- List generated category pages
    if totalCategoryPages > 0 then
        print("\nGenerated category pages in ./output/ directory:")
        for _, page in ipairs(categoryPages) do
            print("  - " .. page.filename .. " (" .. page.title .. ")")
        end
    end

    if settings.sitemap then
        print("\nGenerated sitemap files:")
        print("  - " .. settings.sitemap.mapSaveAs)
        print("  - " .. settings.sitemap.mapFileName)
    end

    print(string.rep("=", 60))
end

-- Check for command line arguments
local args = {...}
if #args > 0 then
    local arg = args[1]
    if arg == "-h" or arg == "--help" then
        print("luassg_pagination - Pagination and sitemap generator")
        print("====================================================")
        print("Usage: lua luassg_pagination.lua")
        print()
        print("Description:")
        print("  Generates paginated category lists and sitemaps based on")
        print("  settings defined in ./data/pagination.xml")
        print("  Works directly with XML data files (no need for generated HTML files)")
        print()
        print("Requirements:")
        print("  - ./data/pagination.xml file with settings")
        print("  - ./templates/pagination/categoryTemplate.html (optional)")
        print("  - ./templates/pagination/sitemapTemplate.html (optional)")
        print("  - XML data files in ./data/[entity]/ directories")
        os.exit(0)
    elseif arg == "-v" or arg == "--version" then
        print("luassg_pagination v1.0")
        print("Part of luassg Static Site Generator")
        os.exit(0)
    end
end

-- Run the main function
local success, err = pcall(main)

if not success then
    print("\n" .. string.rep("=", 60))
    print("ERROR: " .. err)
    print(string.rep("=", 60))
    print("\nTroubleshooting tips:")
    print("1. Check that pagination.xml exists in ./data/ directory")
    print("2. Ensure templates exist in ./templates/pagination/ directory")
    print("3. Check that XML data files exist in ./data/[entity]/ directories")
    print("4. Check file permissions")
    print(string.rep("=", 60))
    os.exit(1)
end