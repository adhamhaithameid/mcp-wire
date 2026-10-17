// Hermetic MCP fixture: HTTP JSON/SSE and newline-delimited stdio.
const http = require('http');
const readline = require('readline');
const tools = [
  { name: 'echo', description: 'echoes text back', inputSchema: { type: 'object', properties: { text: { type: 'string' } } } },
  { name: 'image', description: 'tiny image', inputSchema: { type: 'object' } },
];
const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jm1sAAAAASUVORK5CYII=';
function respond(m, path = '') {
  let result;
  switch (m.method) {
    case 'initialize': result = { protocolVersion: '2025-11-25', capabilities: {}, serverInfo: { name: 'fake-mcp', version: '1' } }; break;
    case 'notifications/initialized': return null;
    case 'ping': result = {}; break;
    case 'tools/list': result = path.includes('pages')
      ? (m.params?.cursor ? { tools: tools.slice(1) } : { tools: tools.slice(0, 1), nextCursor: 'page two' }) : { tools }; break;
    case 'tools/call':
      result = m.params.name === 'image' ? { content: [{ type: 'image', mimeType: 'image/png', data: png }] }
        : m.params.name === 'structured' ? { content: [], structuredContent: { value: 42 } }
        : m.params.name === 'resource-link' ? { content: [{ type: 'resource_link', uri: 'fixture://linked', name: 'linked' }] }
        : m.params.name === 'malformed-content' ? { content: 'invalid' }
        : m.params.name === 'failure' ? { isError: true, content: [{ type: 'text', text: 'fixture failure' }] }
        : { content: [{ type: 'text', text: 'hello from fake tool: ' + JSON.stringify(m.params.arguments) }] }; break;
    case 'resources/list': result = { resources: [{ uri: 'fixture://hello', name: 'hello' }] }; break;
    case 'resources/templates/list': result = { resourceTemplates: [{ uriTemplate: 'fixture://{id}', name: 'item' }] }; break;
    case 'resources/read': result = { contents: [{ uri: m.params.uri, text: 'fixture resource' }] }; break;
    case 'prompts/list': result = { prompts: [{ name: 'review', arguments: [{ name: 'code', required: true }] }] }; break;
    case 'prompts/get': result = { messages: [{ role: 'user', content: { type: 'text', text: m.params.arguments.code || 'review' } }] }; break;
    default: return { jsonrpc: '2.0', id: m.id, error: { code: -32601, message: 'unknown method' } };
  }
  return { jsonrpc: '2.0', id: m.id, result };
}
if (process.argv.includes('--stdio')) {
  readline.createInterface({ input: process.stdin }).on('line', line => {
    const response = respond(JSON.parse(line));
    if (response) console.log(JSON.stringify(response));
  });
} else {
  const server = http.createServer((req, res) => {
    const chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    req.on('end', () => {
      let m;
      try { m = JSON.parse(Buffer.concat(chunks).toString()); } catch { res.writeHead(400); return res.end(); }
      if (req.url.includes('auth') && req.headers.authorization !== 'Bearer fixture-secret') { res.writeHead(401); return res.end('DO NOT LOG fixture-secret'); }
      if (req.url.includes('http-error')) { res.writeHead(500); return res.end('DO NOT LOG fixture-secret'); }
      if (m.method !== 'initialize' && !req.headers['mcp-protocol-version']) { res.writeHead(400); return res.end('missing protocol'); }
      const response = respond(m, req.url);
      if (!response) { res.writeHead(202); return res.end(); }
      if (req.url.includes('malformed')) { res.writeHead(200); return res.end('not JSON or SSE'); }
      if (req.url.includes('json')) { res.writeHead(200, { 'Content-Type': 'application/json' }); return res.end(JSON.stringify(response)); }
      res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Mcp-Session-Id': 'fake-session' });
      res.end('event: message\r\ndata: ' + JSON.stringify(response) + '\r\n\r\nevent: message\r\ndata: {"jsonrpc":"2.0","method":"notifications/progress"}\r\n\r\n');
    });
  });
  server.listen(Number(process.argv[2] || 0), '127.0.0.1', () => console.log(server.address().port));
}
