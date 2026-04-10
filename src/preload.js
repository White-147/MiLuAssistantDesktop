const { contextBridge } = require("electron");

contextBridge.exposeInMainWorld("miluDesktop", {
  platform: process.platform,
  version: require("../package.json").version,
});
