import * as fs from 'fs';
import untypedData from './hotKeyCheetSheet.json' ;

const htlmHeader = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Hotkey Cheetsheet</title>
    <style>
	body {
	    font-family: sans-serif;
	}
	table {
	    border-collapse: collapse;
	}
	td {
	    padding: 0.5em;
	    border: 1px solid #ccc;
	}
	td:first-child {
	    font-weight: bold;
	}
    </style>
</head>
<body>
`;

const htmlFooter = `
</body>
</html>
`;


const header = `
<h1>Hotkey Cheetsheet</h1>
`;

type HotkeyGroup = {
    	name: string;
	commands: {
		name: string;
		command: string;
	}[];
};


const data = untypedData as HotkeyGroup[];
console.log(data, "data");

const tableRows = data.map( group => {
	const groupRows = group.commands.map( command => {
		return `
		<tr>
		    <td>${command.name}</td>
		    <td>${command.command}</td>
		</tr>
		`;
	}
	).join('\n');
	return `
	<tr>
	    <td colspan="2">${group.name}</td>
	</tr>
	${groupRows}
	`;
}
).join('\n');

const table = `
<table>
	${tableRows}
</table>
`;



const htmlPage = htlmHeader + 
	header +
    	table +
	htmlFooter; 


fs.writeFileSync('./hotKeyCheetSheet.html', htmlPage );
