import * as fs from 'fs';
import untypedData from './hotKeyCheetSheet.json';

const htlmHeader = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Hotkey Cheetsheet</title>
	<link rel="stylesheet" href="./hotKeyCheetSheet.css">
	<script src="https://kit.fontawesome.com/1c9c7c4c6b.js" crossorigin="anonymous"></script>

</head>
<body>
`;

const htmlFooter = `
</body>
</html>
`;


const header = `
<div class="card">
    <div class="card-header">
    <h1>Hotkey Cheetsheet</h1>
    </div>
</div>
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

const appCards = data.map(group => {
	const card = group.commands.map(command => {
		return `
		<div class="card-body">
		    <div class="command-name">
			<i class="fa-solid fa-terminal"></i>
			${command.name}
		    </div>
		    <div class="command">
			${command.command}
		    </div>
		</div>
		`;
	}
	).join('\n');
	return `
	<div class="card">
	    <div class="card-header">
		${group.name}
	    </div>
	    ${card}
	</div>
	`;
}
).join('\n');

const flex = `
<div class="flex-container">
    ${appCards}
</div>
`;

const htmlPage = htlmHeader +
	flex +
	htmlFooter;


fs.writeFileSync('./hotKeyCheetSheet.html', htmlPage);

const css = `
body {
	font-family: sans-serif;
	height: 80rem;
	-webkit-print-color-adjust: exact !important;
}
.flex-container {
	display: flex;
	flex-wrap: wrap;
	gap: 1em;
}
.card {
	border: 1px solid #ccc;
	border-radius: 0.5em;
	width: 20em;
}
.card-header {
	background-color: #ccc;
	padding: 0.25em;
	font-weight: bold;
	font-size: 1.5em;
}
.card-body {
	padding: 0.5em;
}
.command-name {
	font-size: 1.25em;
}
.command {
	font-weight: bold;
	background-color: #eee;
}
`;

fs.writeFileSync('./hotKeyCheetSheet.css', css);

