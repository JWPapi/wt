#!/usr/bin/env node
// wt proxy - reverse proxy for worktree dev servers
// Routes <feature>.localhost:3000 → localhost:<deterministic-port>
// Zero dependencies, Node built-ins only.

const http = require("http");
const net = require("net");
const { execSync } = require("child_process");

const LISTEN_PORT = 3000;

// Cache cksum results so we don't shell out on every request
const portCache = new Map();

function getPort(feature) {
  if (portCache.has(feature)) return portCache.get(feature);
  const cksum = execSync(`printf '%s' "${feature}" | cksum | cut -d' ' -f1`, {
    encoding: "utf-8",
  }).trim();
  const port = (Number(cksum) % 997) + 3001;
  portCache.set(feature, port);
  return port;
}

function extractFeature(host) {
  if (!host) return null;
  // "auth-refactor.localhost:3000" → "auth-refactor"
  const hostname = host.split(":")[0];
  const parts = hostname.split(".");
  if (parts.length < 2 || parts[parts.length - 1] !== "localhost") return null;
  // Everything before .localhost is the feature name
  parts.pop(); // remove "localhost"
  return parts.join(".");
}

const server = http.createServer((req, res) => {
  const feature = extractFeature(req.headers.host);
  if (!feature) {
    res.writeHead(400, { "Content-Type": "text/plain" });
    res.end("Bad request: use <feature>.localhost:3000\n");
    return;
  }

  const port = getPort(feature);
  console.log(`${feature}.localhost → :${port}  ${req.method} ${req.url}`);

  const proxyReq = http.request(
    {
      hostname: "127.0.0.1",
      port,
      path: req.url,
      method: req.method,
      headers: req.headers,
    },
    (proxyRes) => {
      res.writeHead(proxyRes.statusCode, proxyRes.headers);
      proxyRes.pipe(res);
    }
  );

  proxyReq.on("error", (err) => {
    console.error(`${feature}.localhost → :${port}  ERROR ${err.code}`);
    res.writeHead(502, { "Content-Type": "text/plain" });
    res.end(`502 Bad Gateway: no server on :${port} (${err.code})\n`);
  });

  req.pipe(proxyReq);
});

// WebSocket / HMR upgrade handling
server.on("upgrade", (req, socket, head) => {
  const feature = extractFeature(req.headers.host);
  if (!feature) {
    socket.destroy();
    return;
  }

  const port = getPort(feature);
  console.log(`${feature}.localhost → :${port}  WS UPGRADE ${req.url}`);

  const upstream = net.connect(port, "127.0.0.1", () => {
    // Replay the original HTTP upgrade request to the upstream server
    const reqLine = `${req.method} ${req.url} HTTP/1.1\r\n`;
    const headers = Object.entries(req.headers)
      .map(([k, v]) => `${k}: ${v}`)
      .join("\r\n");
    upstream.write(reqLine + headers + "\r\n\r\n");
    if (head.length) upstream.write(head);
    upstream.pipe(socket);
    socket.pipe(upstream);
  });

  upstream.on("error", (err) => {
    console.error(`${feature}.localhost → :${port}  WS ERROR ${err.code}`);
    socket.destroy();
  });

  socket.on("error", () => upstream.destroy());
});

server.listen(LISTEN_PORT, () => {
  console.log(`wt proxy listening on :${LISTEN_PORT}`);
  console.log(`Route: <feature>.localhost:${LISTEN_PORT} → deterministic port`);
});
