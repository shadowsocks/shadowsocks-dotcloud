net = require("net");

PORT = process.env.PORT || 5000;
server = net.createServer(function (connection) {
    connection.write('HTTP/1.1 200 OK\r\nContent-Type:text/plain\r\n\r\nd\r\nHello world!\n\r\n');
    setTimeout(function () {
        connection.write('6\r\nOver!\n\r\n0\r\n');
        connection.end();
    }, 5000);

    connection.on("error", function (e) {
    });
});
server.listen(PORT, function () {
    return console.log("server listening at port " + PORT);
});

server.on("error", function (e) {
    if (e.code === "EADDRINUSE") {
        return console.warn("Address in use, aborting");
    }
});
