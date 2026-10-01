// A local server for the web version: serves dist/ on http://localhost:8080 (set PORT to change the port).
// Build and serve in one go: `npm start`.

import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const DIST = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "dist");
const PORT = Number(process.env.PORT) || 8080;
const TYPES = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".json": "application/json" };

http
  .createServer((req, res) => {
    const url = decodeURIComponent(new URL(req.url, "http://localhost").pathname);
    const file = path.join(DIST, url === "/" ? "index.html" : url);
    if (!file.startsWith(DIST + path.sep) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      res.writeHead(404).end("Not found");
      return;
    }
    res.writeHead(200, { "Content-Type": TYPES[path.extname(file)] ?? "application/octet-stream" });
    fs.createReadStream(file).pipe(res);
  })
  .on("error", e => {
    if (e.code !== "EADDRINUSE") throw e;
    console.error(`\nPort ${PORT} is already in use (maybe the demo is already running in another window).`);
    console.error(`Open http://localhost:${PORT} or start on another port: PORT=8081 npm start\n`);
    process.exit(1);
  })
  .listen(PORT, () => {
    console.log(`\nThe demo is running: http://localhost:${PORT}\nStop it with Ctrl + C\n`);
  });
