exports.parseArgs = ->
  options =
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
      if result[lastKey]
        if result[lastKey] not instanceof Array
          result[lastKey] = [result[lastKey]]
        result[lastKey].push oneArg
      else
        result[lastKey] = oneArg
      nextIsValue = false
    else if oneArg of options
      lastKey = options[oneArg]
      nextIsValue = true
  result

exports.version = "shadowsocks-heroku v0.9.7"
