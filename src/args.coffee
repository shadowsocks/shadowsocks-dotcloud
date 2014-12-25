
exports.parseArgs = ->
  defination =
    '-b': 'local_address'
    '-l': 'local_port'
    '-s': 'server'
    '-r': 'remote_port'
    '-k': 'password',
    '-c': 'config_file',
    '-m': 'method'

  result = {}
  nextIsValue = false
  lastKey = null
  for _, oneArg of process.argv
    if nextIsValue
      result[lastKey] = oneArg
      nextIsValue = false
    else if oneArg of defination
      lastKey = defination[oneArg]
      nextIsValue = true
  result

exports.version = "shadowsocks-heroku v0.9.7"
