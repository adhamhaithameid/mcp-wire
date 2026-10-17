// Hermetic Figma fixture. Reject incorrect handshakes and answer actual tool calls.
const http = require('http');
const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jm1sAAAAASUVORK5CYII=';
const server = http.createServer((req, res) => {
  const chunks = [];
  req.on('data', c => chunks.push(c));
  req.on('end', () => {
    let m;
    try { m = JSON.parse(Buffer.concat(chunks).toString()); } catch { res.writeHead(400); return res.end(); }
    let result;
    switch (m.method) {
      case 'initialize': result = { protocolVersion: '2025-11-25', capabilities: { tools: {} }, serverInfo: { name: 'Figma Dev Mode MCP Server', version: '1.0.0' } }; break;
      case 'notifications/initialized': res.writeHead(202); return res.end();
      case 'ping': result = {}; break;
      case 'tools/list': result = { tools: ['get_design_context', 'get_metadata', 'get_screenshot', 'get_variable_defs'].map(name => ({ name, inputSchema: { type: 'object', properties: { nodeId: { type: 'string' } } } })) }; break;
      case 'tools/call':
        if (m.params.name === 'get_screenshot') result = { content: [{ type: 'image', mimeType: 'image/png', data: png }] };
        else if (m.params.name === 'get_variable_defs') result = { content: [{ type: 'text', text: JSON.stringify({ 'color/primary': '#c0392b', 'space/small': '8px' }) }] };
        else if (m.params.name === 'fixture_error') result = { isError: true, content: [{ type: 'text', text: 'fixture error' }] };
        else result = { content: [{ type: 'text', text: 'design node ' + m.params.arguments.nodeId }] };
        break;
      default: res.writeHead(200, { 'Content-Type': 'application/json' }); return res.end(JSON.stringify({ jsonrpc: '2.0', id: m.id, error: { code: -32601, message: 'unsupported' } }));
    }
    res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Mcp-Session-Id': 'fake-session-id' });
    res.end('event: message\ndata: ' + JSON.stringify({ jsonrpc: '2.0', id: m.id, result }) + '\n\n');
  });
});
server.listen(Number(process.argv[2] || 0), '127.0.0.1', () => console.log(server.address().port));
