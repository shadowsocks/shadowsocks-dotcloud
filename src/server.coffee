net = require("net")
fs = require("fs")
path = require("path")
http = require("http")
WebSocket = require('ws')
WebSocketServer = WebSocket.Server
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

wss = new WebSocketServer port: PORT

wss.on "connection", (ws) ->
  console.log "server connected"
  console.log "concurrent connections:", wss.clients.length
  encryptor = new Encryptor(KEY, METHOD)
  stage = 0
  headerLength = 0
  remote = null
  cachedPieces = []
  addrLen = 0
  remoteAddr = null
  remotePort = null
  ws.on "message", (data, flags) ->
    data = encryptor.decrypt data
    if stage is 5
      remote.write(data)
      return
    if stage is 0
      try
        addrtype = data[0]
        if addrtype is 3
          addrLen = data[1]
        else unless addrtype is 1
          console.warn "unsupported addrtype: " + addrtype
          ws.close()
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
          ws.send data, { binary: true } if ws.readyState is WebSocket.OPEN

        remote.on "end", ->
          ws.emit "close"
          console.log "remote disconnected"

        remote.on "error", (e)->
          ws.emit "close"
          console.log "remote: #{e}"

        remote.setTimeout timeout, ->
          console.log "remote timeout"
          remote.destroy()
          ws.close()

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
        remote.destroy() if remote
        ws.close()
    else cachedPieces.push data if stage is 4
      # remote server not connected
      # cache received buffers
      # make sure no data is lost

  ws.on "ping", ->
    ws.pong '', null, true

  ws.on "close", ->
    console.log "server disconnected"
    console.log "concurrent connections:", wss.clients.length
    remote.destroy() if remote

  ws.on "error", (e) ->
    console.warn "server: #{e}"
    console.log "concurrent connections:", wss.clients.length
    remote.destroy() if remote
