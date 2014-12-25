net = require("net")
fs = require("fs")
path = require("path")
http = require("http")
parseArgs = require("minimist")
Encryptor = require("./encrypt").Encryptor

options =
  alias:
    'r': 'remote_port'
    'k': 'password',
    'c': 'config_file',
    'm': 'method'
  string: ['password', 'method', 'config_file']
  default:
    'remote_port': process.env.PORT || 8080
    'password': process.env.KEY
    'method': process.env.METHOD
    'config_file': path.resolve(__dirname, "config.json")

inetNtoa = (buf) ->
  buf[0] + "." + buf[1] + "." + buf[2] + "." + buf[3]

configFromArgs = parseArgs process.argv.slice(2), options
configFile = configFromArgs.config_file
configContent = fs.readFileSync(configFile)
config = JSON.parse(configContent)
for k, v of configFromArgs
  config[k] = v
timeout = Math.floor(config.timeout * 1000)
PORT = config.remote_port
KEY = config.password
METHOD = config.method

server = http.createServer (req, res) ->
  res.writeHead 200, 'Content-Type':'text/plain'
  res.end 'Good Day!'

server.on 'upgrade', (req, connection, head) ->
  connection.write 'HTTP/1.1 101 Web Socket Protocol Handshake\r\n' +
    'Upgrade: WebSocket\r\n' +
    'Connection: Upgrade\r\n' +
    '\r\n'
  console.log "server connected"
  server.getConnections (err, count) ->
    console.log "concurrent connections:", count
    return
  encryptor = new Encryptor(KEY, METHOD)
  stage = 0
  headerLength = 0
  remote = null
  cachedPieces = []
  addrLen = 0
  remoteAddr = null
  remotePort = null
  connection.on "data", (data) ->
    data = encryptor.decrypt data
    if stage is 5
      connection.pause() unless remote.write(data)
      return
    if stage is 0
      try
        addrtype = data[0]
        if addrtype is 3
          addrLen = data[1]
        else unless addrtype is 1
          console.warn "unsupported addrtype: " + addrtype
          connection.end()
          return
        # read address and port
        if addrtype is 1
          remoteAddr = inetNtoa(data.slice(1, 5))
          remotePort = data.readUInt16BE(5)
          headerLength = 7
        else
          remoteAddr = data.slice(2, 2 + addrLen).toString("binary")
          remotePort = data.readUInt16BE(2 + addrLen)
          headerLength = 2 + addrLen + 2
        console.log remoteAddr
        # connect remote server
        remote = net.connect(remotePort, remoteAddr, ->
          console.log "connecting", remoteAddr
          i = 0

          while i < cachedPieces.length
            piece = cachedPieces[i]
            remote.write piece
            i++
          cachedPieces = null # save memory
          stage = 5
        )
        remote.on "data", (data) ->
          data = encryptor.encrypt data
          remote.pause() unless connection.write(data)

        remote.on "end", ->
          console.log "remote disconnected"
          server.getConnections (err, count) ->
            console.log "concurrent connections:", count
            return
          connection.end()

        remote.on "error", (e)->
          console.log "remote : #{e}"
          connection.destroy()
          server.getConnections (err, count) ->
            console.log "concurrent connections:", count
            return

        remote.on "drain", ->
          connection.resume()

        remote.setTimeout timeout, ->
          connection.end()
          remote.destroy()

        if data.length > headerLength
          # make sure no data is lost
          buf = new Buffer(data.length - headerLength)
          data.copy buf, 0, headerLength
          cachedPieces.push buf
          buf = null
        stage = 4
      catch e
        # may encouter index out of range
        console.warn e
        connection.destroy()
        remote.destroy() if remote
    else cachedPieces.push data if stage is 4
      # remote server not connected
      # cache received buffers
      # make sure no data is lost

  connection.on "end", ->
    console.log "server disconnected"
    remote.destroy() if remote
    server.getConnections (err, count) ->
      console.log "concurrent connections:", count
      return

  connection.on "error", (e)->
    console.warn "server: #{e}"
    remote.destroy() if remote
    server.getConnections (err, count) ->
      console.log "concurrent connections:", count
      return

  connection.on "drain", ->
    remote.resume() if remote

  connection.setTimeout timeout, ->
    remote.destroy() if remote
    connection.destroy()

server.listen PORT, ->
  address = server.address()
  console.log "server listening at", address

server.on "error", (e) ->
  console.warn "Address in use, aborting" if e.code is "EADDRINUSE"
  process.exit 1
