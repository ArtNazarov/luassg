# luassg

Static site generator written with Lua

## Templates

Templates must be placed into ./templates directory as .html files
Name of template must be corresponding entity folders from directory ./data
So, template ./templates/product.html used for ./data/product/product-someId.xml file

Use in the templates placeholders like ```{entity.fieldName}```

## Content

Pages must be stored in the directory ./data as xml files like

```
<product id="firstProduct">
    <name>Product 1</name>
    <price>100</price>
    <caption>Some title</caption>
</product>
```
with name pattern entity-id.xml, so in the example above
data must be saved to ./data/product/product-firstProduct.xml

## Usage:

Go to the app folder and run in the terminal

```lua luassg.lua```

Pages will be generated to the folder ./output

### Author

Nazarov A.A., Russia, Orenburg, 2026