'use strict';

// Shows the launcher and engine version in the footer, the macOS builds
// change both outside BAR's release cycle.
const { ipcRenderer } = require('electron');
const { app } = require('@electron/remote');

ipcRenderer.on('config', (e, config) => {
	let label = document.getElementById('version-info');
	if (label == null) {
		label = document.createElement('div');
		label.id = 'version-info';
		label.style.cssText = 'grid-area: links; align-self: end; font-size: 11px; margin-left: -23px; opacity: 0.7; text-shadow: 1px 1px 1px black;';
		document.getElementById('footerLinks').before(label);
	}
	const engine = config.launch.engine_path != null ? null : config.launch.engine || config.downloads.engines[0];
	label.innerText = `Launcher ${app.getVersion()}` + (engine ? ` · Engine ${engine}` : '');
});
