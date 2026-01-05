# luassg

Static site generator written with Lua

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

Go to the app folder and run in the terminal

```lua luassg.lua```

Pages will be generated to the folder `./output`

## Processing Order

Constants from `./data/CONST.xml` are loaded first

For each template, constants (```__CONST.NAME__```) are replaced

Then entity-specific values (```{entity.field}```) are replaced

Generated HTML files are saved to `./output/` directory

## Author

Nazarov A.A., Russia, Orenburg, 2026