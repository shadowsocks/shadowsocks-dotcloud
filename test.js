import child_process from 'child_process';
import local from './local.js';
import server from './server.js';

async function runCurl() {
  const curl = child_process.spawn('curl', [
    '-v',
    'https://example.com',
    '-L',
    '--socks5',
    '127.0.0.1:1080',
  ]);
  curl.on('exit', function (code) {
    if (code === 0) {
      console.log('Test passed');
      process.exit(0);
    } else {
      console.error('Test failed');
      process.exit(code);
    }
  });

  curl.stdout.pipe(process.stdout);
  curl.stderr.pipe(process.stderr);

  await new Promise((r) => {
    curl.on('close', r);
  });
}

while (true) {
  if (local.listening && server.listening) {
    await runCurl();
  }
  await new Promise((r) => setTimeout(r, 100));
}
