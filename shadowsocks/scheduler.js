// Generated by CoffeeScript 1.4.0
(function() {
  var Scheduler;

  Scheduler = (function() {

    function Scheduler(servers) {
      if (servers instanceof Array) {
        this._servers = servers;
      } else {
        this._servers = [servers];
      }
    }

    Scheduler.prototype._servers = [];

    Scheduler.prototype._failureCount = {};

    Scheduler.prototype._successCount = {};

    Scheduler.prototype._ping = {};

    Scheduler.prototype.toString = function() {
      return "[" + this._servers.join(',') + "]";
    };

    Scheduler.prototype._increaseCounter = function(counter, key) {
      if (key in counter) {
        return counter[key]++;
      } else {
        return counter[key] = 1;
      }
    };

    Scheduler.prototype.serverFailed = function(server) {
      console.log("" + server + " failed");
      return this._increaseCounter(this._failureCount, server);
    };

    Scheduler.prototype.serverSucceeded = function(server) {
      console.log("" + server + " succeeded");
      return this._increaseCounter(this._successCount, server);
    };

    Scheduler.prototype.updatePing = function(server, ping) {
      if (server in _ping) {
        return _ping[server] = ping;
      } else {
        return _ping[server] = _ping[server] * 0.8 + ping * 0.2;
      }
    };

    Scheduler.prototype.getServer = function() {
      return this._servers[Math.floor(Math.random() * this._servers.length)];
    };

    return Scheduler;

  })();

  exports.Scheduler = Scheduler;

}).call(this);
