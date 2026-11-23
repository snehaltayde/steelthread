// Shared HTTP helpers: error type, JSON responses, JSON request bodies, malformed-request handler.

const MAX_BODY_BYTES = 100 * 1024;

export class HttpError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

export function sendJson(res, status, body) {
  const text = JSON.stringify(body);
  res.writeHead(status, {
    'content-type': 'application/json',
    'content-length': Buffer.byteLength(text),
  });
  res.end(text);
}

// Reads a JSON request body. Invalid JSON or a body over 100 KB -> HttpError 400 invalid_input.
export function readJson(req) {
  return new Promise((resolve, reject) => {
    const invalid = () => new HttpError(400, 'invalid_input');
    const declared = Number(req.headers['content-length']);
    if (declared > MAX_BODY_BYTES) {
      req.resume(); // drain so the client can read the response
      reject(invalid());
      return;
    }
    const chunks = [];
    let size = 0;
    let done = false;
    const onData = (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        done = true;
        chunks.length = 0;
        req.off('data', onData);
        req.resume();
        reject(invalid());
        return;
      }
      chunks.push(chunk);
    };
    req.on('data', onData);
    req.on('error', () => {
      if (!done) {
        done = true;
        reject(invalid());
      }
    });
    req.on('end', () => {
      if (done) return;
      done = true;
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch {
        reject(invalid());
      }
    });
  });
}

const BAD_REQUEST_BODY = '{"error":"invalid_input"}';
const BAD_REQUEST = [
  'HTTP/1.1 400 Bad Request',
  'content-type: application/json',
  `content-length: ${Buffer.byteLength(BAD_REQUEST_BODY)}`,
  'connection: close',
  '',
  BAD_REQUEST_BODY,
].join('\r\n');

// Malformed HTTP the parser rejects never reaches the app: answer with a fixed JSON 400.
export function attachClientErrorHandler(server) {
  server.on('clientError', (err, socket) => {
    if (err.code === 'ECONNRESET' || !socket.writable) {
      socket.destroy();
      return;
    }
    socket.end(BAD_REQUEST);
  });
  return server;
}
