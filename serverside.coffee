colors = require 'colors'
async = require 'async'
_ = require 'underscore'
helpers = require 'helpers'
Bacbone = require 'backbone4000'
collections = require 'collections/serverside'

lwebTcp = require 'lweb3/transports/server/tcp'
lwebWs = require 'lweb3/transports/server/websocket'

queryProtocol = require 'lweb3/protocols/query'
channelProtocol = require 'lweb3/protocols/channel'

ribcage = require 'ribcage'

util = require 'util'

traceroute = require './traceroute'
geoip = require "geoip-native"
ping = require "net-ping"

request = require 'request'
settings =
    production: false
    module:
        express:
            port: 3006
            static: __dirname + '/static'
            views: __dirname + '/ejs'
            cookiesecret: helpers.rndid(30)

        user: false

env = { settings: settings }

locate = (ip,callback) ->
    request.get 'http://ipinfo.io/' + ip, {json: true}, (e, r, details) ->
        if details.loc
            loc = details.loc.split(',')
            details.loc = { latitude: loc[0], longitude: loc[1] }
        callback details

initRibcage = (env,callback) ->
    express = require 'express'
    ejslocals = require 'ejs-locals'
    connectmongodb = require 'connect-mongodb'

    env.settings.module.express.configure = ->
        env.app.engine 'ejs', ejslocals
        env.app.set 'view engine', 'ejs'
        env.app.set 'views', env.settings.module.express.views
        env.app.use express.compress()
        env.app.use express.favicon()
        env.app.use express.bodyParser()        
        env.app.set 'etag', true
        env.app.set 'x-powered-by', false
        env.app.use env.app.router
        env.app.use express.static(env.settings.module.express.static)
        env.app.use (err, req, res, next) =>
            throw err
            env.log 'web request error', { error: util.inspect(err) }, 'error', 'http'
            console.error util.inspect(err)
            if not env.settings.production then res.send 500, util.inspect(err)
            else res.send 500, 'error 500'
            
    env.logres = (name, callback) ->
        (err,data) -> 
            if (err)
                env.log name + ' (' + colors.red(err) + ")", { error: err }, 'init', 'fail'
            else
                if data?.constructor isnt String then logStr="..." else logStr = " (" + colors.green(data) + ")"
                env.log name + logStr, {}, 'init', 'ok'
            callback(err,data)
            
    ribcage.init env, callback
        
dropPrivileges = (env,callback) ->
    if not env.settings.user then return callback null, colors.magenta("WARNING: staying at uid #{process.getuid()}")

    user = env.settings.user
    group = env.settings.group or user
    try
        process.initgroups user, group
        process.setgid group
        process.setuid user
    catch err
        if err.code is 'EPERM' then return callback null, colors.magenta("WARNING: permission denied")
        else return callback err
    callback null, "dropped to " + user + "/" + group

initLweb = (env,callback) ->
    env.lweb = new lwebWs.webSocketServer http: env.http, verbose: false
    env.lweb.addProtocol new queryProtocol.serverServer verbose: false
    env.lweb.addProtocol new channelProtocol.serverServer verbose: true
    callback()

initRoutes = (env,callback) ->
    logreq = (req,res,next) ->
        host = req.socket.remoteAddress
        if host is "127.0.0.1" then if forwarded = req.headers['x-forwarded-for'] then host = forwarded
        env.log host + " " + req.method + " " + req.originalUrl, { level: 2, ip: host, headers: req.headers, method: req.method }, 'http', req.method, host
        next()

    env.app.use (req, res, next) -> 
      res.header("Access-Control-Allow-Origin", "*")
      res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept")
      next()
    
    env.app.get '*', logreq
    env.app.post '*', logreq
    
    env.app.get '/', (req,res) ->
        res.render 'index', { title: 'vtrace', version: env.version, production: env.settings.production }


    env.lweb.onQuery { ping: String }, (msg,reply) ->
        pings = ping.createSession()
        pings.pingHost msg.ping, (err,data,s,r) ->
            pings.close()
            console.log err,data,r - s, 'ms'
            if err then return reply.end {}
                
            locate msg.ping, (data) -> reply.end(_.extend data, ping: r - s)


    env.lweb.onQuery { trace: String }, (msg,reply) ->
        traceroute.trace msg.trace, (err,hops) ->
            console.log colors.red(msg.trace)
            
            if not hops? or hops?.length < 5 then return reply.end()    
            geoip.lookup hops[4]
            reply.write { hops: hops }
            async.series _.map(hops, ((hop) -> ( (callback) ->
                
                data = {}
                data.ip = ip = _.keys(hop)?[0]
                if not data.ip then return callback()
                data.ping =  hop[data.ip]?[0]
                console.log colors.green(ip)
                locate ip, (details) ->
                    _.extend data, details
                    console.log util.inspect data
                    reply.write data
                    callback()
                )))
            , (err,data) ->
                console.log 'reply end'
                reply.end()

    callback()


initModels = (env,callback) ->
    callback()

init = (env,callback) ->
    async.auto {
        ribcage: (callback) -> initRibcage env, callback
        privileges: [ 'ribcage', (callback) -> dropPrivileges env, env.logres('drop user',callback) ]
        routes: [ 'ribcage', (callback) -> initRoutes env, env.logres('routes',callback) ]
        lweb: [ 'ribcage', (callback) -> initLweb env, env.logres('lweb', callback) ]
        models: [ 'ribcage', (callback) -> initModels env, env.logres('models',callback) ]
        },  callback

init env, (err,data) ->
    if err
        env.log(colors.red('my body is not ready, exiting'), {}, 'init', 'error' )
        process.exit 15
    else
        env.log('application running', {}, 'init', 'completed' )
        console.log colors.green('\n\n\t\t\tMy body is ready\n\n')

