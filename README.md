shadowsocks-heroku
==================

shadowsocks-heroku is a lightweight tunnel proxy which can help you get through
 firewalls. It is a port of [shadowsocks](https://github.com/clowwindy/shadowsocks), but
 through a different protocol.

shadowsocks-heroku uses WebSockets instead of raw sockets,
 so it can be deployed on [heroku](https://www.heroku.com/).

Notice that the protocol is INCOMPATIBLE with the origin shadowsocks.

Usage
-----

    $ heroku create
    Creating still-tor-8707... done, stack is cedar
    http://still-tor-8707.herokuapp.com/ | git@heroku.com:still-tor-8707.git

Put the code somewhere, for example shadowsocks-heroku/. Edit `config.json`, change the following values:

    server          your server hostname, for example: still-tor-8707.herokuapp.com
    local_port      local port
    password        a password used to encrypt transfer
    timeout         in seconds
    method          encryption method, "rc4" by default

Push the code to heroku.

```
$ git push heroku master
Initializing repository, done.
Counting objects: 178, done.
Delta compression using up to 4 threads.
Compressing objects: 100% (97/97), done.
Writing objects: 100% (178/178), 47.42 KiB | 0 bytes/s, done.
Total 178 (delta 89), reused 162 (delta 78)

-----> Node.js app detected
-----> Requested node range:  0.10.x
-----> Resolved node version: 0.10.26
-----> Downloading and installing node
-----> Writing a custom .npmrc to circumvent npm bugs
-----> Exporting config vars to environment
-----> Installing dependencies
       npm WARN package.json shadowsocks-heroku@0.9.6 No repository field.
-----> Cleaning up node-gyp and npm artifacts
-----> Building runtime environment
-----> Discovering process types
       Procfile declares types -> web

-----> Compressing... done, 5.1MB
-----> Launching... done, v3
       http://still-tor-8707.herokuapp.com/ deployed to Heroku

To git@heroku.com:still-tor-8707.git
 * [new branch]      master -> master
```

While in beta, WebSocket functionality must be enabled via the Heroku Labs:

```
$ heroku labs:enable websockets
Enabling websockets for still-tor-8707... done
WARNING: This feature is experimental and may change or be removed without notice.
For more information see: https://devcenter.heroku.com/articles/heroku-labs-websockets
```

Open terminal, run `node local.js`.

Change proxy settings of your browser into

    SOCKS5 127.0.0.1:local_port

Troubleshooting
----------------

If there is something wrong, you can check the logs by:

    $ heroku logs -t --app still-tor-8707
