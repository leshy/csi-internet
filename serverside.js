// Generated by CoffeeScript 1.9.1
(function() {
  var Bacbone, _, async, channelProtocol, collections, colors, dropPrivileges, env, geoip, helpers, init, initLweb, initModels, initRibcage, initRoutes, locate, lwebTcp, lwebWs, ping, queryProtocol, request, ribcage, settings, traceroute, util;

  colors = require('colors');

  async = require('async');

  _ = require('underscore');

  helpers = require('helpers');

  Bacbone = require('backbone4000');

  collections = require('collections/serverside');

  lwebTcp = require('lweb3/transports/server/tcp');

  lwebWs = require('lweb3/transports/server/websocket');

  queryProtocol = require('lweb3/protocols/query');

  channelProtocol = require('lweb3/protocols/channel');

  ribcage = require('ribcage');

  util = require('util');

  traceroute = require('./traceroute');

  geoip = require("geoip-native");

  ping = require("net-ping");

  request = require('request');

  settings = {
    production: false,
    module: {
      express: {
        port: 3006,
        "static": __dirname + '/static',
        views: __dirname + '/ejs',
        cookiesecret: helpers.rndid(30)
      },
      user: false
    }
  };

  env = {
    settings: settings
  };

  locate = function(ip, callback) {
    return request.get('http://ipinfo.io/' + ip, {
      json: true
    }, function(e, r, details) {
      var loc;
      if (details.loc) {
        loc = details.loc.split(',');
        details.loc = {
          latitude: loc[0],
          longitude: loc[1]
        };
      }
      return callback(details);
    });
  };

  initRibcage = function(env, callback) {
    var connectmongodb, ejslocals, express;
    express = require('express');
    ejslocals = require('ejs-locals');
    connectmongodb = require('connect-mongodb');
    env.settings.module.express.configure = function() {
      env.app.engine('ejs', ejslocals);
      env.app.set('view engine', 'ejs');
      env.app.set('views', env.settings.module.express.views);
      env.app.use(express.compress());
      env.app.use(express.favicon());
      env.app.use(express.bodyParser());
      env.app.set('etag', true);
      env.app.set('x-powered-by', false);
      env.app.use(env.app.router);
      env.app.use(express["static"](env.settings.module.express["static"]));
      return env.app.use((function(_this) {
        return function(err, req, res, next) {
          throw err;
          env.log('web request error', {
            error: util.inspect(err)
          }, 'error', 'http');
          console.error(util.inspect(err));
          if (!env.settings.production) {
            return res.send(500, util.inspect(err));
          } else {
            return res.send(500, 'error 500');
          }
        };
      })(this));
    };
    env.logres = function(name, callback) {
      return function(err, data) {
        var logStr;
        if (err) {
          env.log(name + ' (' + colors.red(err) + ")", {
            error: err
          }, 'init', 'fail');
        } else {
          if ((data != null ? data.constructor : void 0) !== String) {
            logStr = "...";
          } else {
            logStr = " (" + colors.green(data) + ")";
          }
          env.log(name + logStr, {}, 'init', 'ok');
        }
        return callback(err, data);
      };
    };
    return ribcage.init(env, callback);
  };

  dropPrivileges = function(env, callback) {
    var err, group, user;
    if (!env.settings.user) {
      return callback(null, colors.magenta("WARNING: staying at uid " + (process.getuid())));
    }
    user = env.settings.user;
    group = env.settings.group || user;
    try {
      process.initgroups(user, group);
      process.setgid(group);
      process.setuid(user);
    } catch (_error) {
      err = _error;
      if (err.code === 'EPERM') {
        return callback(null, colors.magenta("WARNING: permission denied"));
      } else {
        return callback(err);
      }
    }
    return callback(null, "dropped to " + user + "/" + group);
  };

  initLweb = function(env, callback) {
    env.lweb = new lwebWs.webSocketServer({
      http: env.http,
      verbose: false
    });
    env.lweb.addProtocol(new queryProtocol.serverServer({
      verbose: false
    }));
    env.lweb.addProtocol(new channelProtocol.serverServer({
      verbose: true
    }));
    return callback();
  };

  initRoutes = function(env, callback) {
    var logreq;
    logreq = function(req, res, next) {
      var forwarded, host;
      host = req.socket.remoteAddress;
      if (host === "127.0.0.1") {
        if (forwarded = req.headers['x-forwarded-for']) {
          host = forwarded;
        }
      }
      env.log(host + " " + req.method + " " + req.originalUrl, {
        level: 2,
        ip: host,
        headers: req.headers,
        method: req.method
      }, 'http', req.method, host);
      return next();
    };
    env.app.use(function(req, res, next) {
      res.header("Access-Control-Allow-Origin", "*");
      res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
      return next();
    });
    env.app.get('*', logreq);
    env.app.post('*', logreq);
    env.app.get('/', function(req, res) {
      return res.render('index', {
        title: 'vtrace',
        version: env.version,
        production: env.settings.production
      });
    });
    env.lweb.onQuery({
      ping: String
    }, function(msg, reply) {
      var pings;
      pings = ping.createSession();
      return pings.pingHost(msg.ping, function(err, data, s, r) {
        pings.close();
        console.log(err, data, r - s, 'ms');
        if (err) {
          return reply.end({});
        }
        return locate(msg.ping, function(data) {
          return reply.end(_.extend(data, {
            ping: r - s
          }));
        });
      });
    });
    env.lweb.onQuery({
      trace: String
    }, function(msg, reply) {
      return traceroute.trace(msg.trace, function(err, hops) {
        console.log(colors.red(msg.trace));
        if ((hops == null) || (hops != null ? hops.length : void 0) < 5) {
          return reply.end();
        }
        geoip.lookup(hops[4]);
        reply.write({
          hops: hops
        });
        return async.series(_.map(hops, (function(hop) {
          return function(callback) {
            var data, ip, ref, ref1;
            data = {};
            data.ip = ip = (ref = _.keys(hop)) != null ? ref[0] : void 0;
            if (!data.ip) {
              return callback();
            }
            data.ping = (ref1 = hop[data.ip]) != null ? ref1[0] : void 0;
            console.log(colors.green(ip));
            return locate(ip, function(details) {
              _.extend(data, details);
              console.log(util.inspect(data));
              reply.write(data);
              return callback();
            });
          };
        })), function(err, data) {
          console.log('reply end');
          return reply.end();
        });
      });
    });
    return callback();
  };

  initModels = function(env, callback) {
    return callback();
  };

  init = function(env, callback) {
    return async.auto({
      ribcage: function(callback) {
        return initRibcage(env, callback);
      },
      privileges: [
        'ribcage', function(callback) {
          return dropPrivileges(env, env.logres('drop user', callback));
        }
      ],
      routes: [
        'ribcage', function(callback) {
          return initRoutes(env, env.logres('routes', callback));
        }
      ],
      lweb: [
        'ribcage', function(callback) {
          return initLweb(env, env.logres('lweb', callback));
        }
      ],
      models: [
        'ribcage', function(callback) {
          return initModels(env, env.logres('models', callback));
        }
      ]
    }, callback);
  };

  init(env, function(err, data) {
    if (err) {
      env.log(colors.red('my body is not ready, exiting'), {}, 'init', 'error');
      return process.exit(15);
    } else {
      env.log('application running', {}, 'init', 'completed');
      return console.log(colors.green('\n\n\t\t\tMy body is ready\n\n'));
    }
  });

}).call(this);
