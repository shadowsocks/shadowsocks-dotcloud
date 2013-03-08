# test encryption
encrypt = require("./encrypt")
target = [
  [ 60, 53, 84, 138, 217, 94, 88, 23, 39, 242, 219, 35, 12, 157, 165, 181, 255, 143, 83, 247, 162, 16, 31, 209, 190, 171, 115, 65, 38, 41, 21, 245, 236, 46, 121, 62, 166, 233, 44, 154, 153, 145, 230, 49, 128, 216, 173, 29, 241, 119, 64, 229, 194, 103, 131, 110, 26, 197, 218, 59, 204, 56, 27, 34, 141, 221, 149, 239, 192, 195, 24, 155, 170, 183, 11, 254, 213, 37, 137, 226, 75, 203, 55, 19, 72, 248, 22, 129, 33, 175, 178, 10, 198, 71, 77, 36, 113, 167, 48, 2, 117, 140, 142, 66, 199, 232, 243, 32, 123, 54, 51, 82, 57, 177, 87, 251, 150, 196, 133, 5, 253, 130, 8, 184, 14, 152, 231, 3, 186, 159, 76, 89, 228, 205, 156, 96, 163, 146, 18, 91, 132, 85, 80, 109, 172, 176, 105, 13, 50, 235, 127, 0, 189, 95, 98, 136, 250, 200, 108, 179, 211, 214, 106, 168, 78, 79, 74, 210, 30, 73, 201, 151, 208, 114, 101, 174, 92, 52, 120, 240, 15, 169, 220, 182, 81, 224, 43, 185, 40, 99, 180, 17, 212, 158, 42, 90, 9, 191, 45, 6, 25, 4, 222, 67, 126, 1, 116, 124, 206, 69, 61, 7, 68, 97, 202, 63, 244, 20, 28, 58, 93, 134, 104, 144, 227, 147, 102, 118, 135, 148, 47, 238, 86, 112, 122, 70, 107, 215, 100, 139, 223, 225, 164, 237, 111, 125, 207, 160, 187, 246, 234, 161, 188, 193, 249, 252 ],
  [ 151, 205, 99, 127, 201, 119, 199, 211, 122, 196, 91, 74, 12, 147, 124, 180, 21, 191, 138, 83, 217, 30, 86, 7, 70, 200, 56, 62, 218, 47, 168, 22, 107, 88, 63, 11, 95, 77, 28, 8, 188, 29, 194, 186, 38, 198, 33, 230, 98, 43, 148, 110, 177, 1, 109, 82, 61, 112, 219, 59, 0, 210, 35, 215, 50, 27, 103, 203, 212, 209, 235, 93, 84, 169, 166, 80, 130, 94, 164, 165, 142, 184, 111, 18, 2, 141, 232, 114, 6, 131, 195, 139, 176, 220, 5, 153, 135, 213, 154, 189, 238, 174, 226, 53, 222, 146, 162, 236, 158, 143, 55, 244, 233, 96, 173, 26, 206, 100, 227, 49, 178, 34, 234, 108, 207, 245, 204, 150, 44, 87, 121, 54, 140, 118, 221, 228, 155, 78, 3, 239, 101, 64, 102, 17, 223, 41, 137, 225, 229, 66, 116, 171, 125, 40, 39, 71, 134, 13, 193, 129, 247, 251, 20, 136, 242, 14, 36, 97, 163, 181, 72, 25, 144, 46, 175, 89, 145, 113, 90, 159, 190, 15, 183, 73, 123, 187, 128, 248, 252, 152, 24, 197, 68, 253, 52, 69, 117, 57, 92, 104, 157, 170, 214, 81, 60, 133, 208, 246, 172, 23, 167, 160, 192, 76, 161, 237, 45, 4, 58, 10, 182, 65, 202, 240, 185, 241, 79, 224, 132, 51, 42, 126, 105, 37, 250, 149, 32, 243, 231, 67, 179, 48, 9, 106, 216, 31, 249, 19, 85, 254, 156, 115, 255, 120, 75, 16 ]
]
tables = encrypt.getTable("foobar!")
console.log JSON.stringify(tables)
i = 0

while i < 256
  console.assert tables[0][i] is target[0][i]
  console.assert tables[1][i] is target[1][i]
  i++

# test proxy

child_process = require('child_process')
local = child_process.spawn('node', ['local.js'])
server = child_process.spawn('node', ['server.js'])

curlRunning = false

local.on 'exit', (code)->
  server.kill()
  if !curlRunning
    process.exit code

server.on 'exit', (code)->
  local.kill()
  if !curlRunning
    process.exit code

localReady = false
serverReady = false
curlRunning = false

runCurl = ->
  curlRunning = true
  curl = child_process.spawn 'curl', ['-v', 'http://www.example.com/', '-L', '--socks5-hostname', '127.0.0.1:1080']
  curl.on 'exit', (code)->
    local.kill()
    server.kill()
    if code is 0
      console.log 'Test passed'
      process.exit 0
    else
      console.error 'Test failed'
      process.exit code

  curl.stdout.on 'data', (data) ->
    console.log data.toString()

  curl.stderr.on 'data', (data) ->
    console.warn data.toString()

local.stderr.on 'data', (data) ->
  console.warn data.toString()

server.stderr.on 'data', (data) ->
  console.warn data.toString()

local.stdout.on 'data', (data) ->
  console.log data.toString()
  if data.toString().indexOf('listening at port') >= 0
    localReady = true
    if localReady and serverReady and not curlRunning
      runCurl()

server.stdout.on 'data', (data) ->
  console.log data.toString()
  if data.toString().indexOf('listening at port') >= 0
    serverReady = true
    if localReady and serverReady and not curlRunning
      runCurl()

