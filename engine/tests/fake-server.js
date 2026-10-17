// Hermetic MCP fixture: HTTP JSON/SSE and newline-delimited stdio.
const http = require('http');
const readline = require('readline');
const tools = [
  { name: 'echo', description: 'echoes text back\nsecond line of description', inputSchema: { type: 'object', properties: { text: { type: 'string' } } } },
  { name: 'add', description: 'adds numbers', inputSchema: { type: 'object', properties: { a: { type: 'number' }, b: { type: 'number' }, label: { type: 'string' } }, required: ['a','b'] } },
  { name: 'image', description: 'tiny image', inputSchema: { type: 'object' } },
  { name: 'structured', description: 'structured', inputSchema: { type: 'object' } },
  { name: 'resource-link', description: 'link', inputSchema: { type: 'object' } },
  { name: 'malformed-content', description: 'bad', inputSchema: { type: 'object' } },
  { name: 'failure', description: 'fails', inputSchema: { type: 'object' } },
];
const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jm1sAAAAASUVORK5CYII=';
let stats = { notif_auth_ok: 0, notif_auth_missing: 0, deletes: 0, last_protocol_header: '', last_session_header: '' };

function respond(m, path = '') {
  let result;
  switch (m.method) {
    case 'initialize': result = { protocolVersion: '2025-11-25', capabilities: {}, serverInfo: { name: 'fake-mcp', version: '1' } }; break;
    case 'notifications/initialized': return null;
    case 'ping': result = {}; break;
    case 'tools/list':
      if (path.includes('pages')) {
        result = m.params?.cursor ? { tools: tools.slice(1,2) } : { tools: tools.slice(0,1), nextCursor: 'page two' };
      } else { result = { tools }; }
      break;
    case 'tools/call':
      if (m.params.name === 'image') result = { content: [{ type: 'image', mimeType: 'image/png', data: png }] };
      else if (m.params.name === 'add') {
        const a = m.params.arguments.a, b = m.params.arguments.b;
        result = { content: [{ type: 'text', text: String(a+b) + (m.params.arguments.label ? ' '+m.params.arguments.label : '') }] };
      }
      else if (m.params.name === 'structured') result = { content: [], structuredContent: { value: 42 } };
      else if (m.params.name === 'resource-link') result = { content: [{ type: 'resource_link', uri: 'fixture://linked', name: 'linked' }] };
      else if (m.params.name === 'malformed-content') result = { content: 'invalid' };
      else if (m.params.name === 'failure') result = { isError: true, content: [{ type: 'text', text: 'fixture failure' }] };
      else result = { content: [{ type: 'text', text: 'hello from fake tool: ' + JSON.stringify(m.params.arguments) }] };
      break;
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
    if (req.url === '/_stats') { res.writeHead(200, {'Content-Type':'application/json'}); return res.end(JSON.stringify(stats)); }
    if (req.method === 'DELETE') { stats.deletes++; res.writeHead(204); return res.end(); }
    const chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    req.on('end', () => {
      let m;
      try { m = JSON.parse(Buffer.concat(chunks).toString()); } catch { res.writeHead(400); return res.end(); }
      if (req.url.includes('auth')) {
        if (req.headers.authorization !== 'Bearer fixture-secret' || req.headers.authorization !== 'Bearer fixture-secret') {}
        if (req.headers.authorization !== 'Bearer s3cret' && req.url.includes('auth')) {
          // accept both fixture-secret and s3cret? spec uses s3cret for /auth
        }
      }
      // /auth requires Bearer s3cret per spec, but existing tests use fixture-secret; support both
      if (req.url.includes('auth') && req.headers.authorization !== 'Bearer s3cret' && req.headers.authorization !== 'Bearer fixture-secret') {
        res.writeHead(401, {'Content-Type':'application/json'}); return res.end(JSON.stringify({error:{code:-32000,message:'unauthorized'}}));
      }
      if (req.url.includes('http-error')) { res.writeHead(500); return res.end('DO NOT LOG fixture-secret'); }
      if (req.url.includes('slow')) {
        setTimeout(() => {
          let response = respond(m, req.url);
      if (req.url.includes('json') && m.method === 'tools/list' && response && response.result) { response.result = { tools: response.result.tools.slice(0,2) }; }
          res.writeHead(200, {'Content-Type':'text/event-stream','Mcp-Session-Id':'fake-session'});
          res.end('event: message\ndata: ' + JSON.stringify(response) + '\r\n\r\n');
        }, 2000);
        return;
      }
      if (req.url.includes('html')) { res.writeHead(200, {'Content-Type':'text/html'}); return res.end('<html></html>'); }
      if (req.url === '/' || req.url === '') { res.writeHead(404); return res.end('not found'); }
      // protocol header check for non-init
      if (m.method !== 'initialize') {
        stats.last_protocol_header = req.headers['mcp-protocol-version'] || '';
        stats.last_session_header = req.headers['mcp-session-id'] || '';
        if (!req.headers['mcp-protocol-version']) { res.writeHead(400); return res.end('missing protocol'); }
      }
      if (m.method === 'notifications/initialized') {
        if (req.headers.authorization) stats.notif_auth_ok++; else stats.notif_auth_missing++;
        res.writeHead(202); return res.end();
      }
      // auth tracking for /auth
      let response = respond(m, req.url);
      if (req.url.includes('json') && m.method === 'tools/list' && response && response.result) { response.result = { tools: response.result.tools.slice(0,2) }; }
      if (!response) { res.writeHead(202); return res.end(); }
      if (req.url.includes('malformed')) { res.writeHead(200); return res.end('not JSON or SSE'); }
      if (req.url.includes('noisy')) {
        res.writeHead(200, {'Content-Type':'text/event-stream','Mcp-Session-Id':'fake-session'});
        const r = JSON.stringify(response);
        // split JSON across data lines
        const half = Math.floor(r.length/2);
        return res.end('event: message\ndata: {"jsonrpc":"2.0","method":"notifications/progress"}\r\n\r\n' +
          'event: message\ndata: {"jsonrpc":"2.0","id":999,"result":{}}\r\n\r\n' +
          'event: message\ndata: ' + r.slice(0,half) + '\r\n' +
          'data: ' + r.slice(half) + '\r\n\r\n');
      }
      if (req.url.includes('json') || req.url.includes('pages')) {
        // stateless for /json: no session id
        const headers = {'Content-Type':'application/json'};
        if (!req.url.includes('json')) headers['Mcp-Session-Id']='fake-session';
        if (req.url.includes('json')) { /* return first 2 tools */ m = JSON.parse(JSON.stringify(m)); }
        res.writeHead(200, headers);
        return res.end(JSON.stringify(response));
      }
      // default /mcp: SSE with session
      res.writeHead(200, {'Content-Type':'text/event-stream','Mcp-Session-Id':'fake-session'});
      res.end('event: message\r\ndata: ' + JSON.stringify(response) + '\r\n\r\nevent: message\r\ndata: {"jsonrpc":"2.0","method":"notifications/progress"}\r\n\r\n');
    });
  });
  server.listen(Number(process.argv[2] || 0), '127.0.0.1', () => console.log(server.address().port));
}
