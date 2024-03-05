// test proxy

import child_process from 'child_process';

const local = child_process.spawn(process.execPath, ['local.js']);
const server = child_process.spawn(process.execPath, ['server.js']);

let curlRunning = false;

local.on('exit', function (code) {
  server.kill();
  if (!curlRunning) {
    process.exit(code);
  }
});

server.on('exit', function (code) {
  local.kill();
  if (!curlRunning) {
    process.exit(code);
  }
});

let localReady = false;
let serverReady = false;
curlRunning = false;

const runCurl = function () {
  curlRunning = true;
  const curl = child_process.spawn('curl', [
    '-v',
    'https://example.com',
    '-L',
    '--socks5',
    '127.0.0.1:1080',
  ]);
  curl.on('exit', function (code) {
    local.kill();
    server.kill();
    if (code === 0) {
      console.log('Test passed');
      process.exit(0);
    } else {
      console.error('Test failed');
      process.exit(code);
    }
  });

  curl.stdout.on('data', (data) => console.log(data.toString()));

  curl.stderr.on('data', (data) => console.warn(data.toString()));
};

local.stderr.on('data', (data) => console.warn(data.toString()));

server.stderr.on('data', (data) => console.warn(data.toString()));

local.stdout.on('data', function (data) {
  console.log(data.toString());
  if (data.toString().indexOf('listening at') >= 0) {
    localReady = true;
    if (localReady && serverReady && !curlRunning) {
      runCurl();
    }
  }
});

server.stdout.on('data', function (data) {
  console.log(data.toString());
  if (data.toString().indexOf('listening at') >= 0) {
    serverReady = true;
    if (localReady && serverReady && !curlRunning) {
      runCurl();
    }
  }
});
