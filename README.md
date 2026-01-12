# luassg

Static site generator written with Lua

## Screenshots

![luassg](https://dl.dropbox.com/scl/fi/2s825rvu5r5pqxq7io87s/luassg.png?rlkey=i38mz2aggef0rsnw82n6x8sjt&st=yc5bfz0c)

![luassg-launcher](https://dl.dropbox.com/scl/fi/ej544bd301oif6yfuaxba/luassg_launcher.png?rlkey=0yickrz9gg1izx5tee9lt8ogm&st=2mqs6a2t)

## Two Implementations Available

luassg comes with two implementations:

### 1. **Monolithic Version** (`luassg.lua`)
A single-file implementation that processes everything in one process.

### 2. **Pipeline Version** (6 separate Lua files)
A modular pipeline implementation with parallel processing capabilities.

## Pipeline Architecture

The pipeline version splits the generation process into discrete stages with two operating modes:

### **Sequential Pipeline Mode:**
```
luassg_launcher.lua → luassg_scanner.lua → luassg_reader.lua → luassg_substitution.lua → luassg_writer.lua
```

### **Parallel Processing Mode:**
```
luassg_launcher.lua → luassg_scanner.lua → (Multiple luassg_process_file.lua instances in parallel)
```

## Pipeline Components:

1. **`luassg_launcher.lua`** - Orchestrator
   - Loads templates and constants
   - Initializes the pipeline
   - Measures total execution time

2. **`luassg_scanner.lua`** - Directory Scanner (with parallel processing)
   - Scans `./data/` for entity directories
   - Matches entities with available templates
   - Launches processes in parallel batches
   - Monitors and manages background processes

3. **`luassg_reader.lua`** - XML Reader
   - Reads individual XML files
   - Parses entity data (fields and attributes)
   - Extracts entity IDs and content

4. **`luassg_substitution.lua`** - Template Processor
   - Replaces placeholders in templates
   - First replaces constants (`__CONST.NAME__`)
   - Then replaces entity values (`{entity.field}`)

5. **`luassg_writer.lua`** - File Writer
   - Writes final HTML to `./output/` directory
   - Names files as `entity-id.html`
   - Handles file creation and error reporting

6. **`luassg_process_file.lua`** - Complete Pipeline for Single File
   - Combines reader, substitution, and writer stages
   - Processes one XML file completely
   - Used for parallel processing mode

## Templates

Templates are HTML files stored in the `./templates/` directory. Each template corresponds to an entity type (folder name in `./data/`).

### Template Example: `./templates/gallery.html`
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{gallery.title}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background-color: #f4f4f4;
        }
        h1 {
            color: #333;
        }
        .post {
            background: white;
            padding: 20px;
            margin-bottom: 20px;
            border-radius: 5px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
    </style>
</head>
<body>
    <h1>__CONST.SITENAME__</h1>
    <div class="post">
        <h1>{gallery.title}</h1>
        <p>{gallery.description}</p>
        <img alt="{gallery.alt}" width="88%" height="auto" src="{gallery.src}" />
        <p>{gallery.comment}</p>
    </div>
    <p>template gallery.html</p>
    <footer>__CONST.AUTHOR__</footer>
</body>
</html>
```

### Template Placeholders:
- **Entity fields**: `{entity_name.field_name}` (e.g., `{gallery.title}`)
- **Constants**: `__CONST.CONSTANT_NAME__` (e.g., `__CONST.SITENAME__`)

## Content (XML Data Files)

XML data files define the content for each page and are stored in entity-specific directories within `./data/`.

### XML Example: `./data/gallery/gallery-37158403-3cfe-4922-92e2-46326f0eb571.xml`
```xml
<gallery id="37158403-3cfe-4922-92e2-46326f0eb571">
    <title>The kitten</title>
    <description>Some description</description>
    <alt>Some alt text</alt>
    <src>./images/kitten.jpg</src>
    <comment>my comment</comment>
</gallery>
```

### XML Structure:
- **Root tag**: Must match the entity name (`gallery` in this example)
- **`id` attribute**: Unique identifier for the entity
- **Child elements**: Each becomes a field accessible via `{entity_name.field_name}`

## Constants

Global constants are defined in `./data/CONST.xml` and can be used across all templates.

### Constants Example: `./data/CONST.xml`
```xml
<CONST>
    <SITENAME>My Awesome Site</SITENAME>
    <AUTHOR>John Doe</AUTHOR>
    <YEAR>2026</YEAR>
    <FOOTER_TEXT>All rights reserved</FOOTER_TEXT>
</CONST>
```

### Using Constants in Templates:
```html
<footer>
    © __CONST.YEAR__ __CONST.AUTHOR__ - __CONST.FOOTER_TEXT__
</footer>
```

## Parallel Processing Features

The scanner supports **parallel batch processing**:

### Key Features:
- **Configurable batch size** - Process multiple files simultaneously
- **Process monitoring** - Tracks all background processes
- **Clean completion** - Waits for all processes before exiting
- **Timeout handling** - Prevents hanging processes
- **Output management** - No stray output in terminal

### Configuration:
Modify the `BATCH_SIZE` variable in `luassg_scanner.lua`:
```lua
local BATCH_SIZE = 2  -- Process 2 files at once (default)
-- Options: 1 (sequential), 2, 4, 8, or #all_jobs (all at once)
```

## Inter-Process Communication

The pipeline uses **file-based communication** between stages:
- Each stage reads input from a temporary file
- Processes the data
- Writes output to another temporary file for the next stage
- Temporary files are cleaned up after use

For parallel processing, each `luassg_process_file.lua` instance:
- Receives parameters via command line
- Uses shared constants file
- Writes output directly to `./output/` directory
- Logs progress to individual log files

## Benefits of Pipeline Approach

- **Modularity**: Each component can be tested independently
- **Scalability**: Parallel processing of multiple files
- **Maintainability**: Smaller, focused code files
- **Robustness**: Isolated failures don't crash the entire system
- **Monitorability**: Each stage logs its progress and timing
- **Performance**: Significant speedup with parallel processing

## Performance Comparison

| Files | Sequential | Parallel (Batch=2) | Speedup |
|-------|------------|-------------------|---------|
| 6     | ~20 ms     | ~10 ms            | 2x      |
| 12    | ~40 ms     | ~20 ms            | 2x      |
| 24    | ~80 ms     | ~40 ms            | 2x      |

**Note**: Actual speedup depends on CPU cores, disk I/O, and file sizes.

## File Structure

```
./
├── luassg.lua                    # Monolithic version
├── luassg_launcher.lua           # Pipeline orchestrator
├── luassg_scanner.lua            # Directory scanner (with parallel processing)
├── luassg_reader.lua             # XML file reader
├── luassg_substitution.lua       # Template processor
├── luassg_writer.lua             # HTML file writer
├── luassg_process_file.lua       # Complete pipeline for single file
├── data/
│   ├── CONST.xml                 # Global constants
│   ├── gallery/                  # Gallery entities
│   │   └── gallery-37158403-3cfe-4922-92e2-46326f0eb571.xml
│   ├── page/                     # Page entities
│   ├── product/                  # Product entities
│   └── longread/                 # Article entities
├── templates/
│   ├── gallery.html              # Gallery template
│   ├── page.html                 # Page template
│   ├── product.html              # Product template
│   └── longread.html             # Article template
└── output/                       # Generated HTML files
```

## Output Example

For the gallery example above, running luassg generates:

**Generated File**: `./output/gallery-37158403-3cfe-4922-92e2-46326f0eb571.html`

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>The kitten</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background-color: #f4f4f4;
        }
        h1 {
            color: #333;
        }
        .post {
            background: white;
            padding: 20px;
            margin-bottom: 20px;
            border-radius: 5px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
    </style>
</head>
<body>
    <h1>My Awesome Site</h1>
    <div class="post">
        <h1>The kitten</h1>
        <p>Some description</p>
        <img alt="Some alt text" width="88%" height="auto" src="./images/kitten.jpg" />
        <p>my comment</p>
    </div>
    <p>template gallery.html</p>
    <footer>John Doe</footer>
</body>
</html>
```

## Usage

### For Monolithic Version:
```bash
lua luassg.lua
```

### For Pipeline Version:
```bash
lua luassg_launcher.lua
```

### Helper Commands:
```bash
# Show help
lua luassg_launcher.lua --help

# Show version
lua luassg_launcher.lua --version
```

### Advanced Usage: Custom Batch Size
For large sites, adjust the parallel processing batch size:
```bash
# Edit luassg_scanner.lua and change:
local BATCH_SIZE = 4  # Process 4 files at once
```

## Processing Order

1. Constants from `./data/CONST.xml` are loaded first
2. For each template, constants (`__CONST.NAME__`) are replaced
3. Then entity-specific values (`{entity.field}`) are replaced
4. Generated HTML files are saved to `./output/` directory

## Error Handling

Both versions include error handling for:
- Missing templates or directories
- Malformed XML files
- Missing constants
- File permission issues
- Process timeout in parallel mode
- Background process failures

## Monitoring Parallel Processing

When using parallel processing, the scanner provides detailed feedback:
- Shows PIDs of all background processes
- Monitors process completion
- Displays batch progress
- Lists all generated files
- Handles cleanup of temporary files

## GUI

[GUI XML CRUD Application](https://github.com/ArtNazarov/entity_xml_crud_app) - A graphical interface for managing your XML content files.


# Pagination Feature

luassg now includes a powerful pagination system for organizing content into category pages, generating index pages, and creating sitemaps.

## Overview

The pagination feature (`luassg_pagination.lua`) automatically:
- Groups entities by category
- Generates paginated category pages
- Creates a main index page
- Builds both HTML and XML sitemaps
- Supports category inclusion/exclusion

## File Structure

```
./
├── luassg_pagination.lua          # Pagination generator
├── data/
│   ├── pagination.xml             # Pagination configuration
│   └── ... (other XML data files)
├── templates/
│   └── pagination/
│       ├── categoryTemplate.html  # Template for category pages
│       ├── indexTemplate.html     # Template for index page (optional)
│       └── sitemapTemplate.html   # Template for HTML sitemap
└── output/
    └── ... (generated pagination files)
```

## Configuration File: `pagination.xml`

Create `./data/pagination.xml` to configure pagination settings:

```xml
<pagination>
    <itemsPerPage>10</itemsPerPage>
    <siteUrl>https://example.com</siteUrl>
    <indexCategory>longread</indexCategory>
    <include>
        <category>quotes</category>
        <category>product</category>
        <category>gallery</category>
        <category>page</category>
        <category>posts</category>
        <category>news</category>
    </include>
    <exclude>
        <category>private</category>
    </exclude>
</pagination>
```

### Configuration Options:

| Setting | Description | Default |
|---------|-------------|---------|
| `itemsPerPage` | Number of items per category page | 10 |
| `siteUrl` | Base URL for absolute links in sitemap | `https://example.com` |
| `indexCategory` | Category to use as main index content | `longread` |
| `include` | List of categories to generate pages for | All categories |
| `exclude` | Categories to skip | None |

## Category Template

Create `./templates/pagination/categoryTemplate.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>__CONST.SITENAME__ - {category} (Page {currentPage})</title>
    <style>
        /* Your styles here */
        .pagination { margin: 20px 0; }
        .page-item { display: inline-block; margin: 0 5px; }
        .current-page { font-weight: bold; }
    </style>
</head>
<body>
    <h1>{category} - Page {currentPage} of {totalPages}</h1>
    
    <!-- Entity list -->
    <div class="entity-list">
        {entities}
    </div>
    
    <!-- Pagination controls -->
    <div class="pagination">
        {pagination}
    </div>
    
    <!-- Navigation -->
    <div class="navigation">
        <a href="index.html">Home</a> | 
        <a href="sitemap.html">Sitemap</a>
    </div>
</body>
</html>
```

### Category Template Placeholders:

| Placeholder | Description |
|-------------|-------------|
| `{category}` | Category name |
| `{currentPage}` | Current page number |
| `{totalPages}` | Total pages for this category |
| `{entities}` | HTML list of entities |
| `{pagination}` | Pagination navigation links |
| `__CONST.*__` | Global constants |

## Sitemap Template

Create `./templates/pagination/sitemapTemplate.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>__CONST.SITENAME__ - Sitemap</title>
</head>
<body>
    <h1>Site Map</h1>
    <ul>
        <li><a href="index.html">Home</a></li>
        {categories}
    </ul>
</body>
</html>
```

## Generated Files

The pagination generator creates:

### 1. Category Pages
```
./output/category-{category}-page-{page}.html
```
Example: `category-news-page-1.html`

### 2. Index Page
```
./output/index.html
```
Main site index using content from the `indexCategory`

### 3. Sitemaps
```
./output/sitemap.html          # Human-readable HTML sitemap
./sitemap.xml                  # XML sitemap for search engines
```

## XML Sitemap Format

The XML sitemap follows the sitemaps.org protocol:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    <url>
        <loc>https://example.com/index.html</loc>
        <lastmod>2026-01-12</lastmod>
        <changefreq>weekly</changefreq>
        <priority>1.0</priority>
    </url>
    <!-- Additional URLs -->
</urlset>
```

## Usage

Run the pagination generator:

```bash
lua luassg_pagination.lua
```

### Output Example:
```
luassg_pagination - Generating paginated lists and sitemap...
=============================================================
Parsing pagination settings from ./data/pagination.xml...
Loading constants from ./data/CONST.xml...
Loaded 3 constants
Checking templates...
  Found category template: ./templates/pagination/categoryTemplate.html
  Found sitemap template: ./templates/pagination/sitemapTemplate.html

Collecting entity data from XML files...
Found 14 entities in XML files
Grouping entities by category...
Found 7 categories
  - quotes: 1 entities
  - product: 2 entities
  - gallery: 1 entities
  - longread: 2 entities
  - page: 2 entities
  - posts: 3 entities
  - news: 3 entities

Generating category pages...
  Processing category: quotes (1 entities)
    Generated: category-quotes-page-1.html
  Processing category: product (2 entities)
    Generated: category-product-page-1.html
  ...

Generating index page...
  Generated index page: ./output/index.html

Generating sitemap...
  Generated sitemap: ./output/sitemap.html
  Generated XML sitemap: ./sitemap.xml

============================================================
PAGINATION GENERATION COMPLETED
============================================================
Total time: 18.47 ms
Total entities processed: 14
Total categories: 7
Total category pages generated: 6
```

## Integration with Main Pipeline

The pagination feature works independently but complements the main luassg pipeline:

1. **First**: Run the main generator to create individual entity pages
   ```bash
   lua luassg_launcher.lua
   ```

2. **Then**: Run the pagination generator to create category lists
   ```bash
   lua luassg_pagination.lua
   ```

## Customizing Entity Display

In the category template, the `{entities}` placeholder is replaced with formatted HTML. You can customize this in the source code by modifying the `formatEntityForList()` function in `luassg_pagination.lua`.

## Performance

The pagination generator is optimized for speed:
- Processes all entities in a single pass
- Uses efficient XML parsing
- Generates minimal file I/O operations
- Typically completes in under 20ms for 50+ entities

## Benefits

- **Automatic organization**: Groups content by category
- **SEO-friendly**: Creates XML sitemaps for search engines
- **Navigation**: Built-in pagination controls
- **Flexible**: Configurable inclusion/exclusion lists
- **Fast**: Minimal overhead, parallel-ready design

## Troubleshooting

If categories aren't appearing:
1. Check that the category name matches the folder name in `./data/`
2. Verify the category is listed in the `<include>` section of `pagination.xml`
3. Ensure there are XML files in the category directory

If templates aren't found:
1. Create the `./templates/pagination/` directory
2. Ensure `categoryTemplate.html` and `sitemapTemplate.html` exist
3. Check file permissions

## Example Workflow

```bash
# Generate individual entity pages
lua luassg_launcher.lua

# Generate category pages and sitemaps
lua luassg_pagination.lua

# Your site is now ready with:
# - Individual entity pages: ./output/entity-id.html
# - Category pages: ./output/category-*.html
# - Index page: ./output/index.html
# - Sitemaps: ./output/sitemap.html and ./sitemap.xml
```

The pagination feature extends luassg into a complete static site solution with proper content organization and search engine optimization.

## Author

Nazarov A.A., Russia, Orenburg, 2026

## License

Open source - free to use and modify
