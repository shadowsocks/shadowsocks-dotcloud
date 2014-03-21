var http = require('http');

// Create an HTTP server
var srv = http.createServer(function (req, res) {
    res.writeHead(200, {'Content-Type':'text/plain'});
    console.log('okay');
    res.end('okay');
});
srv.on('upgrade', function (req, socket, head) {
    socket.write('HTTP/1.1 101 Web Socket Protocol Handshake\r\n' +
        'Upgrade: WebSocket\r\n' +
        'Connection: Upgrade\r\n' +
        '\r\n');
    socket.on('data', function (data) {
        console.log('srv on data');
        console.log(data);
        socket.write('hello');
    });

//  socket.pipe(socket); // echo back
});

// now that server is running
srv.listen(1337, '127.0.0.1', function () {

    // make a request
    var options = {
        port:1337,
        host:'127.0.0.1',
        headers:{
            'Connection':'Upgrade',
            'Upgrade':'websocket'
        }
    };

    var req = http.request(options);
    req.end();

    req.on('upgrade', function (res, socket, upgradeHead) {
        console.log('got upgraded!');
        socket.write('test');
        socket.on('data', function (data) {
            console.log('req on data');
            console.log(data);
        });
//    socket.end();
//    process.exit(0);
    });
});