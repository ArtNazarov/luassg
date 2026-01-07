# luassg

Static site generator written with Lua

## Screenshot

![luassg](https://dl.dropbox.com/scl/fi/2s825rvu5r5pqxq7io87s/luassg.png?rlkey=i38mz2aggef0rsnw82n6x8sjt&st=yc5bfz0c)

## Two Implementations Available

luassg comes with two implementations:

### 1. **Monolithic Version** (`luassg.lua`)
A single-file implementation that processes everything in one process.

### 2. **Pipeline Version** (5 separate Lua files)
A modular pipeline implementation where each stage is a separate process.

## Pipeline Architecture

The pipeline version splits the generation process into discrete stages:

```
luassg_launcher.lua → luassg_scanner.lua → luassg_reader.lua → luassg_substitution.lua → luassg_writer.lua
```

### Pipeline Components:

1. **`luassg_launcher.lua`** - Orchestrator
   - Loads templates and constants
   - Initializes the pipeline
   - Measures total execution time

2. **`luassg_scanner.lua`** - Directory Scanner
   - Scans `./data/` for entity directories
   - Matches entities with available templates
   - Launches reader processes for each XML file

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

## Inter-Process Communication

The pipeline uses **file-based communication** between stages:
- Each stage reads input from a temporary file
- Processes the data
- Writes output to another temporary file for the next stage
- Temporary files are cleaned up after use

## Benefits of Pipeline Approach

- **Modularity**: Each component can be tested independently
- **Scalability**: Potential for parallel processing of multiple files
- **Maintainability**: Smaller, focused code files
- **Robustness**: Isolated failures don't crash the entire system
- **Monitorability**: Each stage logs its progress and timing

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

## Processing Order

Constants from `./data/CONST.xml` are loaded first

For each template, constants (```__CONST.NAME__```) are replaced

Then entity-specific values (```{entity.field}```) are replaced

Generated HTML files are saved to `./output/` directory

## Performance

The pipeline implementation provides detailed performance metrics:
- Individual file processing times
- Total generation time
- Template and constant loading times
- File I/O performance

## Error Handling

Both versions include error handling for:
- Missing templates or directories
- Malformed XML files
- Missing constants
- File permission issues

## File Structure

```
./
├── luassg.lua                    # Monolithic version
├── luassg_launcher.lua           # Pipeline orchestrator
├── luassg_scanner.lua            # Directory scanner
├── luassg_reader.lua             # XML file reader
├── luassg_substitution.lua       # Template processor
├── luassg_writer.lua             # HTML file writer
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

## Author

Nazarov A.A., Russia, Orenburg, 2026

## License

Open source - free to use and modify