"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
var fs = require("fs");
var htlmHeader = "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n    <meta charset=\"UTF-8\">\n    <title>Hotkey Cheetsheet</title>\n    <style>\n\tbody {\n\t    font-family: sans-serif;\n\t}\n\ttable {\n\t    border-collapse: collapse;\n\t}\n\ttd {\n\t    padding: 0.5em;\n\t    border: 1px solid #ccc;\n\t}\n\ttd:first-child {\n\t    font-weight: bold;\n\t}\n    </style>\n</head>\n<body>\n";
var htmlFooter = "\n</body>\n</html>\n";
var header = "\n<h1>Hotkey Cheetsheet</h1>\n";
var htmlPage = htlmHeader +
    header +
    htmlFooter;
fs.writeFileSync('./foo2.html', htmlPage);
