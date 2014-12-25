net = require("net")
http = require("http")
fs = require("fs")
path = require("path")
parseArgs = require("minimist")
Encryptor = require("./encrypt").Encryptor

options =
  alias:
    'b': 'local_address'
    'l': 'local_port'
    's': 'server'
    'r': 'remote_port'
    'k': 'password',
    'c': 'config_file',
    'm': 'method'
  string: ['local_address', 'server', 'password',
           'config_file', 'method']
  default:
    'local_address': '127.0.0.1'
    'local_port': 1080
    'remote_port': 80
    'config_file': path.resolve(__dirname, "config.json")

inetNtoa = (buf) ->
  buf[0] + "." + buf[1] + "." + buf[2] + "." + buf[3]

configFromArgs = parseArgs process.argv.slice(2), options
configContent = fs.readFileSync(configFromArgs.config_file)
config = JSON.parse(configContent)
for k, v of configFromArgs
  config[k] = v

SERVER = config.server
REMOTE_PORT = config.remote_port
LOCAL_ADDRESS = config.local_address
PORT = config.local_port
KEY = config.password
METHOD = config.method
timeout = Math.floor(config.timeout * 1000)

getServer = ->
  if SERVER instanceof Array
    SERVER[Math.floor(Math.random() * SERVER.length)]
  else
    SERVER

server = net.createServer((connection) ->
  console.log "local connected"
  server.getConnections (err, count) ->
    console.log "concurrent connections:", count
    return
  encryptor = new Encryptor(KEY, METHOD)
  stage = 0
  headerLength = 0
  remote = null
  req = null
  cachedPieces = []
  addrLen = 0
  remoteAddr = null
  remotePort = null
  addrToSend = ""
  aServer = getServer()
  connection.on "data", (data) ->
    if stage is 5
      # pipe sockets
      data = encryptor.encrypt data
      connection.pause() unless remote.write(data)
      return
    if stage is 0
      tempBuf = new Buffer(2)
      tempBuf.write "\u0005\u0000", 0
      connection.write tempBuf
      stage = 1
      return
    if stage is 1
      try
        # +----+-----+-------+------+----------+----------+
        # |VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
        # +----+-----+-------+------+----------+----------+
        # | 1  |  1  | X'00' |  1   | Variable |    2     |
        # +----+-----+-------+------+----------+----------+

        #cmd and addrtype
        cmd = data[1]
        addrtype = data[3]
        unless cmd is 1
          console.log "unsupported cmd:", cmd
          reply = new Buffer("\u0005\u0007\u0000\u0001", "binary")
          connection.end reply
          return
        if addrtype is 3
          addrLen = data[4]
        else unless addrtype is 1
          console.log "unsupported addrtype:", addrtype
          connection.end()
          return
        addrToSend = data.slice(3, 4).toString("binary")
        # read address and port
        if addrtype is 1
          remoteAddr = inetNtoa(data.slice(4, 8))
          addrToSend += data.slice(4, 10).toString("binary")
          remotePort = data.readUInt16BE(8)
          headerLength = 10
        else
          remoteAddr = data.slice(5, 5 + addrLen).toString("binary")
          addrToSend += data.slice(4, 5 + addrLen + 2).toString("binary")
          remotePort = data.readUInt16BE(5 + addrLen)
          headerLength = 5 + addrLen + 2
        buf = new Buffer(10)
        buf.write "\u0005\u0000\u0000\u0001", 0, 4, "binary"
        buf.write "\u0000\u0000\u0000\u0000", 4, 4, "binary"
        buf.writeInt16BE remotePort, 8
        connection.write buf
        # connect remote server
        req = http.request(
          host: aServer,
          port: REMOTE_PORT,
          headers:
            'Connection': 'Upgrade',
            'Upgrade': 'websocket'
        )
        req.setNoDelay true
        req.end()
        req.setTimeout timeout, ->
          req.abort()
          connection.end()
        req.on 'error', (e)->
          console.warn "req #{e}"
          req.abort()
          connection.end()
        req.on 'upgrade', (res, conn, upgradeHead) ->
          remote = conn
          console.log "remote got upgrade"
          console.log "connecting #{remoteAddr} via #{aServer}"
          addrToSendBuf = new Buffer(addrToSend, "binary")
          addrToSendBuf = encryptor.encrypt addrToSendBuf
          remote.write addrToSendBuf
          i = 0

          while i < cachedPieces.length
            piece = cachedPieces[i]
            piece = encryptor.encrypt piece
            remote.write piece
            i++
          cachedPieces = null # save memory
          stage = 5

          remote.on "data", (data) ->
            data = encryptor.decrypt data
            remote.pause() unless connection.write(data)

          remote.on "end", ->
            console.log "remote disconnected"
            connection.end()
            server.getConnections (err, count) ->
              console.log "concurrent connections:", count
              return

          remote.on "error", (e)->
            console.log "remote #{remoteAddr}:#{remotePort} error: #{e}"
            if stage is 4
              connection.destroy()
              return
            connection.end()
            server.getConnections (err, count) ->
              console.log "concurrent connections:", count
              return

          remote.on "drain", ->
            connection.resume()

          remote.setTimeout timeout, ->
            connection.end()
            remote.destroy()

        if data.length > headerLength
          buf = new Buffer(data.length - headerLength)
          data.copy buf, 0, headerLength
          cachedPieces.push buf
          buf = null
        stage = 4
      catch e
      # may encounter index out of range
        console.log e
        connection.destroy()
        remote.destroy() if remote
    else cachedPieces.push data if stage is 4
      # remote server not connected
      # cache received buffers
      # make sure no data is lost

  connection.on "end", ->
    remote.destroy() if remote
    server.getConnections (err, count) ->
      console.log "concurrent connections:", count
      return

  connection.on "error", (e)->
    console.log "local error: #{e}"
    req.abort() if req
    remote.destroy() if remote
    server.getConnections (err, count) ->
      console.log "concurrent connections:", count
      return

  connection.on "drain", ->
    # calling resume() when remote not is connected will crash node.js
    remote.resume() if remote and stage is 5

  connection.setTimeout timeout, ->
    req.abort() if req
    remote.destroy() if remote
    connection.destroy()
)

server.listen PORT, LOCAL_ADDRESS, ->
  address = server.address()
  console.log "server listening at", address

server.on "error", (e) ->
  console.log "Address in use, aborting" if e.code is "EADDRINUSE"
  process.exit 1
