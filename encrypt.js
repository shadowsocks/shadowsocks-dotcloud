import crypto from 'crypto';
const int32Max = Math.pow(2, 32);

const cachedTables = {}; // password: [encryptTable, decryptTable]

const getTable = function (key) {
  if (cachedTables[key]) {
    return cachedTables[key];
  }
  console.log('calculating ciphers');
  let table = new Array(256);
  const decrypt_table = new Array(256);
  const md5sum = crypto.createHash('md5');
  md5sum.update(key);
  const hash = Buffer.from(md5sum.digest(), 'binary');
  const al = hash.readUInt32LE(0);
  const ah = hash.readUInt32LE(4);
  let i = 0;

  while (i < 256) {
    table[i] = i;
    i++;
  }
  i = 1;

  while (i < 1024) {
    table.sort(
      (x, y) =>
        (((ah % (x + i)) * int32Max + al) % (x + i)) -
        (((ah % (y + i)) * int32Max + al) % (y + i)),
    );
    i++;
  }
  i = 0;
  while (i < 256) {
    decrypt_table[table[i]] = i;
    ++i;
  }
  const result = [table, decrypt_table];
  cachedTables[key] = result;
  return result;
};

const substitute = function (table, buf) {
  let i = 0;

  while (i < buf.length) {
    buf[i] = table[buf[i]];
    i++;
  }
  return buf;
};

const bytes_to_key_results = {};

const EVP_BytesToKey = function (password, key_len, iv_len) {
  if (bytes_to_key_results[`${password}:${key_len}:${iv_len}`]) {
    return bytes_to_key_results[`${password}:${key_len}:${iv_len}`];
  }
  const m = [];
  let i = 0;
  let count = 0;
  while (count < key_len + iv_len) {
    const md5 = crypto.createHash('md5');
    let data = password;
    if (i > 0) {
      data = Buffer.concat([m[i - 1], password]);
    }
    md5.update(data);
    const d = md5.digest();
    m.push(d);
    count += d.length;
    i += 1;
  }
  const ms = Buffer.concat(m);
  const key = ms.slice(0, key_len);
  const iv = ms.slice(key_len, key_len + iv_len);
  bytes_to_key_results[password] = [key, iv];
  return [key, iv];
};

const method_supported = {
  'aes-128-cfb': [16, 16],
  'aes-192-cfb': [24, 16],
  'aes-256-cfb': [32, 16],
  'bf-cfb': [16, 8],
  'camellia-128-cfb': [16, 16],
  'camellia-192-cfb': [24, 16],
  'camellia-256-cfb': [32, 16],
  'cast5-cfb': [16, 8],
  'des-cfb': [8, 8],
  'idea-cfb': [16, 8],
  'rc2-cfb': [16, 8],
  'seed-cfb': [16, 16],
};

class Encryptor {
  constructor(key, method) {
    this.key = key;
    this.method = method;
    this.iv_sent = false;
    if (this.method === 'table') {
      this.method = null;
    }
    if (this.method) {
      this.cipher = this.get_cipher(
        this.key,
        this.method,
        1,
        crypto.randomBytes(32),
      );
    } else {
      [this.encryptTable, this.decryptTable] = getTable(this.key);
    }
  }

  get_cipher_len(method) {
    method = method.toLowerCase();
    return method_supported[method];
  }

  get_cipher(password, method, op, iv) {
    method = method.toLowerCase();
    password = Buffer.from(password, 'binary');
    const m = this.get_cipher_len(method);
    if (m) {
      const [key, iv_] = EVP_BytesToKey(password, m[0], m[1]);
      if (!iv) {
        iv = iv_;
      }
      if (op === 1) {
        this.cipher_iv = iv.slice(0, m[1]);
      }
      iv = iv.slice(0, m[1]);
      if (op === 1) {
        return crypto.createCipheriv(method, key, iv);
      } else {
        return crypto.createDecipheriv(method, key, iv);
      }
    }
  }

  encrypt(buf) {
    if (this.method) {
      const result = this.cipher.update(buf);
      if (this.iv_sent) {
        return result;
      } else {
        this.iv_sent = true;
        return Buffer.concat([this.cipher_iv, result]);
      }
    } else {
      return substitute(this.encryptTable, buf);
    }
  }

  decrypt(buf) {
    if (this.method) {
      let result;
      if (!this.decipher) {
        const decipher_iv_len = this.get_cipher_len(this.method)[1];
        const decipher_iv = buf.slice(0, decipher_iv_len);
        this.decipher = this.get_cipher(this.key, this.method, 0, decipher_iv);
        result = this.decipher.update(buf.slice(decipher_iv_len));
        return result;
      } else {
        result = this.decipher.update(buf);
        return result;
      }
    } else {
      return substitute(this.decryptTable, buf);
    }
  }
}

export {Encryptor, getTable};
