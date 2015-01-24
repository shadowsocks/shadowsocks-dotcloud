shadowsocks-heroku
==================

shadowsocks-heroku is a lightweight tunnel proxy which can help you get through firewalls. It is a port of [shadowsocks](https://github.com/clowwindy/shadowsocks), but through a different protocol.

shadowsocks-heroku uses WebSocket instead of raw sockets, so it can be deployed on [Heroku](https://www.heroku.com/) and [OpenShift](https://www.openshift.com/).

Notice that the protocol is INCOMPATIBLE with the origin shadowsocks.

Heroku
------

### Usage

```
$ heroku create
Creating still-tor-8707... done, stack is cedar-14
http://still-tor-8707.herokuapp.com/ | git@heroku.com:still-tor-8707.git
```

Push the code to Heroku.

```
$ git push heroku master
…
-----> Compressing... done, 5.1MB
-----> Launching... done, v3
       http://still-tor-8707.herokuapp.com/ deployed to Heroku

To git@heroku.com:still-tor-8707.git
 * [new branch]      master -> master
```

Set a few configs:

```
$ heroku config:set METHOD=rc4 KEY=foobar
Setting config vars and restarting still-tor-8707... done, v11
KEY:    foobar
METHOD: rc4
```

Install project dependencies with `npm install`:

```
$ npm install
…
minimist@1.1.0 node_modules/minimist

ws@0.6.4 node_modules/ws
├── options@0.0.6
├── ultron@1.0.1
└── nan@1.4.1
```

Then run:

```
$ node local.js -s still-tor-8707.herokuapp.com -l 1080 -m rc4 -k foobar -r 80
server listening at { address: '0.0.0.0', family: 'IPv4', port: 1080 }
```

Change proxy settings of your browser into:

```
SOCKS5 127.0.0.1:1080
```

### Troubleshooting

If there is something wrong, you can check the logs by:

```
$ heroku logs -t --app still-tor-8707
```

OpenShift
---------

### Usage

```
$ rhc app create asdfasdf nodejs-0.10
Application Options
-------------------
Domain:     qwert
Cartridges: nodejs-0.10
Gear Size:  default
Scaling:    no

Creating application 'asdfasdf' ... done
…

Your application 'asdfasdf' is now available.

  URL:        http://asdfasdf-qwert.rhcloud.com/
  SSH to:     54b5e30d4382ec020700010d@asdfasdf-qwert.rhcloud.com
  Git remote: ssh://54b5e30d4382ec020700010d@asdfasdf-qwert.rhcloud.com/~/git/asdfasdf.git/
  Cloned to:  …/shadowsocks-heroku/asdfasdf

Run 'rhc show-app asdfasdf' for more details about your app.
```

Push the code to OpenShift.

```
$ git remote add openshift ssh://54b5e30d4382ec020700010d@asdfasdf-qwert.rhcloud.com/~/git/asdfasdf.git
$ git push openshift -f
…
remote: npm info ok
remote: Preparing build for deployment
remote: Deployment id is 5b7aa220
remote: Activating deployment
remote: Starting NodeJS cartridge
remote: Tue Jan 13 2015 22:42:36 GMT-0500 (EST): Starting application 'asdfasdf' ...
remote: -------------------------
remote: Git Post-Receive Result: success
remote: Activation status: success
remote: Deployment completed with status: success
To ssh://54b5e30d4382ec020700010d@asdfasdf-qwert.rhcloud.com/~/git/asdfasdf.git
 + 641794d...a3e1061 master -> master (forced update)
```

Set a few configs:

```
$ rhc env set METHOD=rc4 KEY=foobar -a asdfasdf
Setting environment variable(s) ... done
```

Restart application:

```
$ rhc app restart -a asdfasdf
RESULT:
asdfasdf restarted
```

Install project dependencies with `npm install`:

```
$ npm install
…
minimist@1.1.0 node_modules/minimist

ws@0.6.4 node_modules/ws
├── options@0.0.6
├── ultron@1.0.1
└── nan@1.4.1
```

Then run:

```
$ node local.js -m rc4 -k foobar -s 'wss://asdfasdf-qwert.rhcloud.com:8443'
server listening at { address: '127.0.0.1', family: 'IPv4', port: 1080 }
```

Change proxy settings of your browser into:

```
SOCKS5 127.0.0.1:1080
```

### Troubleshooting

If there is something wrong, you can check the logs by:

```
$ rhc tail -a asdfasdf
```

Supported Ciphers
-----------------

- rc4
- rc4-md5
- table
- bf-cfb
- des-cfb
- rc2-cfb
- idea-cfb
- seed-cfb
- cast5-cfb
- aes-128-cfb
- aes-192-cfb
- aes-256-cfb
- camellia-256-cfb
- camellia-192-cfb
- camellia-128-cfb
