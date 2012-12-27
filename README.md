shadowsocks-dotcloud
===========

shadowsocks-dotcloud is a lightweight tunnel proxy which can help you get through
 firewalls. It is a port of [shadowsocks](https://github.com/clowwindy/shadowsocks), but
 through a different protocol.

shadowsocks-dotcloud uses WebSockets instead of raw sockets,
 so it can be deployed on [dotcloud](https://www.dotcloud.com/).

Notice that the protocol is INCOMPATIBLE with the origin shadowsocks.

usage
-----------

Sign up for [dotcloud](https://www.dotcloud.com/).

Install [dotcloud CLI](https://docs.dotcloud.com/0.9/firststeps/install/).

Put the code somewhere, for example shadowsocks-dotcloud/. Edit `shadowsocks/config.json`, change the following values:

    local_port      local port
    password        a password used to encrypt transfer
    timeout         in seconds

Upload the code. You can choose your own app name other than `shadowsocks`. You'll see your hostname at the end.

    $ dotcloud create shadowsocks
    Created application "shadowsocks" using the flavor "sandbox"
    ...
    $ dotcloud push shadowsocks shadowsocks-dotcloud/
    # upload shadowsocks-dotcloud/ ssh://dotcloud@uploader.dotcloud.com:443/shadowsocks
    ...
    Deployment finished. Your application is available at the following URLs
    www: http://shadowsocks-YOURUSERNAME.dotcloud.com/

Edit `shadowsocks/config.json`, change the following values:

    server          your server hostname, for example, shadowsocks-xxxxxx.dotcloud.com

Open terminal, cd into shadowsocks, run `node local.js`.

Change proxy settings of your browser into

    SOCKS5 127.0.0.1:local_port


troubleshooting
----------------

If there is something wrong, you can check the logs by:

    $ dotcloud logs shadowsocks.www
