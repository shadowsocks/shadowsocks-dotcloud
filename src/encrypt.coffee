crypto = require("crypto")
merge_sort = require("./merge_sort").merge_sort
int32Max = Math.pow(2, 32)

cachedTables = {} # password: [encryptTable, decryptTable]

getTable = (key) ->
  if cachedTables[key]
    return cachedTables[key]
  console.log "calculating ciphers"
  table = new Array(256)
  decrypt_table = new Array(256)
  md5sum = crypto.createHash("md5")
  md5sum.update key
  hash = new Buffer(md5sum.digest(), "binary")
  al = hash.readUInt32LE(0)
  ah = hash.readUInt32LE(4)
  i = 0

  while i < 256
    table[i] = i
    i++
  i = 1

  while i < 1024
    table = merge_sort(table, (x, y) ->
      ((ah % (x + i)) * int32Max + al) % (x + i) - ((ah % (y + i)) * int32Max + al) % (y + i)
    )
    i++
  i = 0
  while i < 256
    decrypt_table[table[i]] = i
    ++i
  result = [table, decrypt_table]
  cachedTables[key] = result
  result

encrypt = (table, buf) ->
  i = 0

  while i < buf.length
    buf[i] = table[buf[i]]
    i++
  buf

class Encryptor
  constructor: (key, @method) ->
    if @method is null
      return
    else if @method == "table"
      [@encryptTable, @decryptTable] = getTable(key)
    else
      @cipher = crypto.createCipher @method, key
      @decipher = crypto.createDecipher @method, key

  encrypt: (buf) ->
    if @method is null
      buf
    else if @method == "table"
      encrypt @encryptTable, buf
    else
      @cipher.update(buf)

  decrypt: (buf) ->
    if @method is null
      buf
    else if @method == "table"
      encrypt @decryptTable, buf
    else
      @decipher.update(buf)

exports.Encryptor = Encryptor
exports.getTable = getTable
