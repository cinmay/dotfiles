"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
var fs = __importStar(require("fs"));
var hotKeyCheetSheet_json_1 = __importDefault(require("./hotKeyCheetSheet.json"));
var htlmHeader = "<!DOCTYPE html>\n    <html lang=\"en\">\n<head>\n    <meta charset=\"UTF-8\">\n    <title>Hotkey Cheetsheet</title>\n\t<link rel=\"stylesheet\" href=\"./hotKeyCheetSheet.css\">\n\t<script src=\"https://kit.fontawesome.com/1c9c7c4c6b.js\" crossorigin=\"anonymous\"></script>\n\n</head>\n<body>\n";
var htmlFooter = "\n</body>\n</html>\n";
var header = "\n<div class=\"card\">\n    <div class=\"card-header\">\n    <h1>Hotkey Cheetsheet</h1>\n    </div>\n</div>\n";
var data = hotKeyCheetSheet_json_1.default;
console.log(data, "data");
var appCards = data
    .map(function (group) {
    var card = group.commands
        .map(function (command) {
        return "\n\t\t<div class=\"card-body\">\n\t\t    <div class=\"command-name\">\n\t\t\t<i class=\"fa-solid fa-terminal\"></i>\n\t\t\t".concat(command.name, "\n\t\t    </div>\n\t\t    <div class=\"command\">\n\t\t\t").concat(command.command, "\n\t\t    </div>\n\t\t</div>\n\t\t");
    })
        .join("\n");
    return "\n\t<div class=\"card\">\n\t    <div class=\"card-header\">\n\t\t".concat(group.name, "\n\t    </div>\n\t    ").concat(card, "\n\t</div>\n\t");
})
    .join("\n");
var flex = "\n<div class=\"flex-container\">\n    ".concat(appCards, "\n</div>\n");
var htmlPage = htlmHeader + flex + htmlFooter;
fs.writeFileSync("./hotKeyCheetSheet.html", htmlPage);
var css = "\nbody {\n\tfont-family: sans-serif;\n\theight: 80rem;\n\t-webkit-print-color-adjust: exact !important;\n}\n.flex-container {\n\tdisplay: flex;\n\tflex-wrap: wrap;\n\tgap: 1em;\n}\n.card {\n\tborder: 1px solid #ccc;\n\tborder-radius: 0.5em;\n\twidth: 20em;\n}\n.card-header {\n\tbackground-color: #ccc;\n\tpadding: 0.25em;\n\tfont-weight: bold;\n\tfont-size: 1.5em;\n}\n.card-body {\n\tpadding: 0.5em;\n}\n.command-name {\n\tfont-size: 1.25em;\n}\n.command {\n\tfont-weight: bold;\n\tbackground-color: #eee;\n}\n";
fs.writeFileSync("./hotKeyCheetSheet.css", css);
