const net = require('net');
const url = require('url');
const http = require('http');
const fs = require('fs');
const path = require('path');
const WebSocket = require('ws');
const parseArgs = require('minimist');
const HttpsProxyAgent = require('https-proxy-agent');
const { Encryptor } = require('./encrypt');

const options = {
  alias: {
    b: 'local_address',
    l: 'local_port',
    s: 'server',
    r: 'remote_port',
    k: 'password',
    c: 'config_file',
    m: 'method'
  },
  string: [
    'local_address',
    'server',
    'password',
    'config_file',
    'method',
    'scheme'
  ],
  default: {
    config_file: path.resolve(__dirname, 'config.json')
  }
};

const inetNtoa = buf => buf[0] + '.' + buf[1] + '.' + buf[2] + '.' + buf[3];

const configFromArgs = parseArgs(process.argv.slice(2), options);
const configContent = fs.readFileSync(configFromArgs.config_file);
const config = JSON.parse(configContent);
for (let k in configFromArgs) {
  const v = configFromArgs[k];
  config[k] = v;
}

const SCHEME = config.scheme;
let SERVER = config.server;
const REMOTE_PORT = config.remote_port;
const LOCAL_ADDRESS = config.local_address;
const PORT = config.local_port;
const KEY = config.password;
let METHOD = config.method;
const timeout = Math.floor(config.timeout * 1000);

if (['', 'null', 'table'].includes(METHOD.toLowerCase())) {
  METHOD = null;
}

const HTTPPROXY = process.env.http_proxy;

if (HTTPPROXY) {
  console.log('http proxy:', HTTPPROXY);
}

const prepareServer = function(address) {
  const serverUrl = url.parse(address);
  serverUrl.slashes = true;
  if (!serverUrl.protocol) {
    serverUrl.protocol = SCHEME;
  }
  if (!serverUrl.hostname) {
    serverUrl.hostname = address;
    serverUrl.pathname = '/';
  }
  if (!serverUrl.port) {
    serverUrl.port = REMOTE_PORT;
  }
  return url.format(serverUrl);
};

if (SERVER instanceof Array) {
  SERVER = SERVER.map(s => prepareServer(s));
} else {
  SERVER = prepareServer(SERVER);
}

const getServer = function() {
  if (SERVER instanceof Array) {
    return SERVER[Math.floor(Math.random() * SERVER.length)];
  } else {
    return SERVER;
  }
};

var server = net.createServer(function(connection) {
  console.log('local connected');
  server.getConnections(function(err, count) {
    console.log('concurrent connections:', count);
  });
  const encryptor = new Encryptor(KEY, METHOD);
  let stage = 0;
  let headerLength = 0;
  let cachedPieces = [];
  let addrLen = 0;
  let ws = null;
  let ping = null;
  let remoteAddr = null;
  let remotePort = null;
  let addrToSend = '';
  const aServer = getServer();
  connection.on('data', function(data) {
    if (stage === 5) {
      // pipe sockets
      data = encryptor.encrypt(data);
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(data, { binary: true });
      }
      return;
    }
    if (stage === 0) {
      const tempBuf = new Buffer(2);
      tempBuf.write('\u0005\u0000', 0);
      connection.write(tempBuf);
      stage = 1;
      return;
    }
    if (stage === 1) {
      try {
        // +----+-----+-------+------+----------+----------+
        // |VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
        // +----+-----+-------+------+----------+----------+
        // | 1  |  1  | X'00' |  1   | Variable |    2     |
        // +----+-----+-------+------+----------+----------+

        //cmd and addrtype
        const cmd = data[1];
        const addrtype = data[3];
        if (cmd !== 1) {
          console.log('unsupported cmd:', cmd);
          const reply = new Buffer('\u0005\u0007\u0000\u0001', 'binary');
          connection.end(reply);
          return;
        }
        if (addrtype === 3) {
          addrLen = data[4];
        } else if (addrtype !== 1) {
          console.log('unsupported addrtype:', addrtype);
          connection.end();
          return;
        }
        addrToSend = data.slice(3, 4).toString('binary');
        // read address and port
        if (addrtype === 1) {
          remoteAddr = inetNtoa(data.slice(4, 8));
          addrToSend += data.slice(4, 10).toString('binary');
          remotePort = data.readUInt16BE(8);
          headerLength = 10;
        } else {
          remoteAddr = data.slice(5, 5 + addrLen).toString('binary');
          addrToSend += data.slice(4, 5 + addrLen + 2).toString('binary');
          remotePort = data.readUInt16BE(5 + addrLen);
          headerLength = 5 + addrLen + 2;
        }
        let buf = new Buffer(10);
        buf.write('\u0005\u0000\u0000\u0001', 0, 4, 'binary');
        buf.write('\u0000\u0000\u0000\u0000', 4, 4, 'binary');
        buf.writeUInt16BE(remotePort, 8);
        connection.write(buf);
        // connect to remote server
        // ws = new WebSocket aServer, protocol: "binary"

        if (HTTPPROXY) {
          // WebSocket endpoint for the proxy to connect to
          const endpoint = aServer;
          const parsed = url.parse(endpoint);
          //console.log('attempting to connect to WebSocket %j', endpoint);

          // create an instance of the `HttpsProxyAgent` class with the proxy server information
          const opts = url.parse(HTTPPROXY);

          // IMPORTANT! Set the `secureEndpoint` option to `false` when connecting
          //            over "ws://", but `true` when connecting over "wss://"
          opts.secureEndpoint = parsed.protocol
            ? parsed.protocol == 'wss:'
            : false;

          const agent = new HttpsProxyAgent(opts);

          ws = new WebSocket(aServer, {
            protocol: 'binary',
            agent
          });
        } else {
          ws = new WebSocket(aServer, {
            protocol: 'binary'
          });
        }

        ws.on('open', function() {
          console.log(`connecting ${remoteAddr} via ${aServer}`);
          let addrToSendBuf = new Buffer(addrToSend, 'binary');
          addrToSendBuf = encryptor.encrypt(addrToSendBuf);
          ws.send(addrToSendBuf, { binary: true });
          let i = 0;

          while (i < cachedPieces.length) {
            let piece = cachedPieces[i];
            piece = encryptor.encrypt(piece);
            ws.send(piece, { binary: true });
            i++;
          }
          cachedPieces = null; // save memory
          stage = 5;

          ping = setInterval(() => ws.ping('', null, true), 50 * 1000);
        });

        ws.on('message', function(data, flags) {
          data = encryptor.decrypt(data);
          connection.write(data);
        });

        ws.on('close', function() {
          clearInterval(ping);
          console.log('remote disconnected');
          connection.destroy();
        });

        ws.on('error', function(e) {
          console.log(`remote ${remoteAddr}:${remotePort} error: ${e}`);
          connection.destroy();
          server.getConnections(function(err, count) {
            console.log('concurrent connections:', count);
          });
        });

        if (data.length > headerLength) {
          buf = new Buffer(data.length - headerLength);
          data.copy(buf, 0, headerLength);
          cachedPieces.push(buf);
          buf = null;
        }
        stage = 4;
      } catch (error) {
        // may encounter index out of range
        const e = error;
        console.log(e);
        connection.destroy();
      }
    } else if (stage === 4) {
      // remote server not connected
      // cache received buffers
      // make sure no data is lost
      cachedPieces.push(data);
    }
  });

  connection.on('end', function() {
    console.log('local disconnected');
    if (ws) {
      ws.terminate();
    }
    server.getConnections(function(err, count) {
      console.log('concurrent connections:', count);
    });
  });

  connection.on('error', function(e) {
    console.log(`local error: ${e}`);
    if (ws) {
      ws.terminate();
    }
    server.getConnections(function(err, count) {
      console.log('concurrent connections:', count);
    });
  });

  connection.setTimeout(timeout, function() {
    console.log('local timeout');
    connection.destroy();
    if (ws) {
      ws.terminate();
    }
  });
});

server.listen(PORT, LOCAL_ADDRESS, function() {
  const address = server.address();
  console.log('server listening at', address);
});

server.on('error', function(e) {
  if (e.code === 'EADDRINUSE') {
    console.log('address in use, aborting');
  }
  process.exit(1);
});
