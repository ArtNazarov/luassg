# luassg

Static site generator written with Lua

## Screenshot

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

6. **`luassg_process_file.lua`** - Complete Pipeline for Single File (NEW)
   - Combines reader, substitution, and writer stages
   - Processes one XML file completely
   - Used for parallel processing mode

## Parallel Processing Features

The scanner now supports **parallel batch processing**:

### Key Features:
- **Configurable batch size** - Process multiple files simultaneously
- **Process monitoring** - Tracks all background processes
- **Clean completion** - Waits for all processes before exiting
- **Timeout handling** - Prevents hanging processes
- **Output management** - No stray output in terminal

### How Parallel Processing Works:
1. Scanner finds all XML files across entity directories
2. Files are grouped into batches (default: 2 files per batch)
3. Each file in a batch is processed by a separate `luassg_process_file.lua` instance
4. Scanner monitors all processes and waits for completion
5. Results are displayed after all files are processed

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

## Templates

Templates must be placed into `./templates` directory as .html files

Name of template must be corresponding entity folders from directory `./data`

So, template `./templates/product.html` used for `./data/product/product-someId.xml` file

Use in the templates placeholders like ```{entity.fieldName}```

## Constants

Global constants can be defined in `./data/CONST.xml` file with the following format:

```xml
<CONST>
    <SITENAME>My Awesome Site</SITENAME>
    <AUTHOR>John Doe</AUTHOR>
    <YEAR>2026</YEAR>
    <FOOTER_TEXT>All rights reserved</FOOTER_TEXT>
</CONST>
```

Use constants in templates with double underscore syntax: `__CONST.CONSTNAME__`

Example in template:
```
<footer>
    © __CONST.YEAR__ __CONST.AUTHOR__ - __CONST.FOOTER_TEXT__
</footer>
```

Constants are replaced before entity-specific values, so you can use them anywhere in your templates.

## Content

Pages must be stored in the directory `./data` as xml files like

```xml
<product id="firstProduct">
    <name>Product 1</name>
    <price>100</price>
    <caption>Some title</caption>
</product>
```

with name pattern entity-id.xml, so in the example above
data must be saved to `./data/product/product-firstProduct.xml`

## Usage

### For Monolithic Version:
```bash
lua luassg.lua
```

### For Pipeline Version:
```bash
lua luassg_launcher.lua
```

Or use the helper commands:
```bash
# Show help
lua luassg_launcher.lua --help

# Show version
lua luassg_launcher.lua --version
```

Pages will be generated to the folder `./output`

## Advanced Usage: Custom Batch Size

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

## File Structure

```
./
├── luassg.lua                    # Monolithic version
├── luassg_launcher.lua           # Pipeline orchestrator
├── luassg_scanner.lua            # Directory scanner (with parallel processing)
├── luassg_reader.lua             # XML file reader
├── luassg_substitution.lua       # Template processor
├── luassg_writer.lua             # HTML file writer
├── luassg_process_file.lua       # Complete pipeline for single file (parallel mode)
├── data/
│   ├── CONST.xml                 # Global constants
│   ├── page/                     # Page entities
│   ├── product/                  # Product entities
│   └── longread/                 # Article entities
├── templates/
│   ├── page.html                 # Page template
│   ├── product.html              # Product template
│   └── longread.html             # Article template
└── output/                       # Generated HTML files
```

## Monitoring Parallel Processing

When using parallel processing, the scanner provides detailed feedback:
- Shows PIDs of all background processes
- Monitors process completion
- Displays batch progress
- Lists all generated files
- Handles cleanup of temporary files

## GUI

[GUI XML CRUD Application](https://github.com/ArtNazarov/entity_xml_crud_app)

## Author

Nazarov A.A., Russia, Orenburg, 2026

## License

Open source - free to use and modify
