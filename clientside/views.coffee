Backbone = require 'backbone4000'
helpers = require 'helpers'
async = require 'async'
_ = window._ =  require 'underscore'
$ = require 'jquery-browserify'


UpdatingCollectionView = Backbone.View.extend
        initialize: (options) ->
            _.extend @, options
            
            if not @_childViewConstructor
                throw "need child view constructor"
                
            if not @_childViewTagName
                throw "need child view tag name"

            @_childViews = []
            
            @collection.each (model) => @addChild model
            @listenTo @collection, 'add', (model) => @addChild model
            @listenTo @collection, 'remove', (model) => @removeChild model

        appendAnim: (root,child,callback) ->
            root.append child; helpers.cbc callback
            
        removeAnim: (child, callback) ->
            child.fadeOut helpers.cb(callback)

        addChild: (model) ->
            childView = new @_childViewConstructor tagName: @_childViewTagName, model: model
            @_childViews.push childView
                
            if @._rendered
                if @_childViews.length is 1 then @removeAnim @$el.children()
                @appendAnim @$el, childView.render().$el

        removeChild: (model) ->
            viewToRemove = _.first _.filter @_childViews, (view) -> view.model is model    
            @_childViews = _.without @_childViews, viewToRemove
            if @._rendered then @removeAnim viewToRemove.$el, -> viewToRemove.remove()

        render: ->
            @_rendered = true
            
            if @_childViews.length then @$el.empty()
                
            _.each @_childViews, (view) =>
                view.render()
                @$el.append view.$el
            @


init = exports.init = (env,callback) ->     
    exports.defineView = defineView = (name,options,classes...) ->
            if options.template
                viewTemplate =
                    template: options.template
                    render: ->
                        if @template.constructor is Function
                            rendering = @template _.extend({ env: env, helpers: helpers, h: helpers, _: _ }, @model.attributes)
                        else
                            rendering = @template

                        @$el.html rendering
                        @
                        
                    initialize: (@initoptions={}) ->
                        if not options.nohook
                            if @model.refresh then @listenTo @model,'anychange', => @render() # remotemodel?
                            else @listenTo @model,'change', => @render()
                            @listenTo @model,'resolve', => @render()
                            
                classes = [viewTemplate].concat classes

            # extend existing or create new?
            if exports[name] then classes.unshift exports[name]:: 

            # compose renderers
            renders = _.pluck _.reject(classes, (c) -> not c.render), 'render'
            if renders.length > 1 then classes.push { render: _.compose.apply(_, renders.reverse()) }

            exports[name] = Backbone.View.extend4000.apply Backbone.View, classes

    defineView "main", template: require('./ejs/main.ejs'), nohook: true,
        render: ->
            @collectionView = new UpdatingCollectionView
                collection: @model
                _childViewTagName: 'div',
                _childViewConstructor: exports.presenceEntry,
                appendAnim: (root,child,callback) ->
                    child.hide()
                    root.prepend child
                    child.fadeIn 'fast', callback
                el: @$('.collection')

            console.log 'new mapview'
            @mapView = new exports.map el: @$('.map'), model: @model
            @mapView.render()
            @collectionView.render()

    defineView "map", template: "", nohook: true,
        render: ->
            @$el.height $(window).height()

            window.map = @map = map = new Datamap
                element: @el
                responsive: true
                fills:
                    #defaultFill: "#eaeaea"
                    defaultFill: "#2C2C43"
                    red: 'red'
                    
                fillOpacity:0.5

                geographyConfig:
                    highlightOnHover: false
                    hideAntarctica: true
                    borderWidth: 1
                    borderColor: "#585886"
                    #borderColor: "black"
                
                arcConfig:
                  strokeColor: '#00ff00'
                  strokeWidth: 1
                  arcSharpness: 1
                  animationSpeed: 600

            el = @el
            map.addPlugin 'heatMap', ( layer, data ) ->
                if not @_heatMap
                    @_heatMap = heatMap = h337.create
                        container: el                        
                        gradient: {
                            '.5': 'rgba(0,0,0,0)',
                            '.75': '#ff0000',
                            '1': '#00ff00'
                        }

                else heatMap = @_heatMap
                
                heatMap.setData max:0, data: []
                max = 0
                
                
                data = _.map data, (entry) =>
                    [ entry.x, entry.y ] = @latLngToXY(entry.latitude, entry.longitude)
                    if entry.val > max then max = entry.val    
                    entry

                distance = (entry1, entry2) -> Math.abs(entry1.x - entry2.x) + Math.abs(entry1.y - entry2.y)
                    
                    
                data = _.map data, (entry) =>
                    r = _.reduce data, ((radius,entryCompare) ->
                        if entry is entryCompare then return radius
                        if (d = distance(entry, entryCompare)) < radius then return d
                        else return radius
                        ), 200
                        
                    
                    if (entry.radius = Math.round(r / 2)) < 20 then entry.radius = 20
                    
                    entry
                    
                console.log data
                @bubbles data
#                heatMap.setData max: max, data: data
                
                console.log max
                                                            
            arcs = []
            bubbles = []
            heatz = []

            env.gogo2 = ->
                ips = [
                    "79.165.48.166",
                    "88.198.25.92",
                    "81.226.67.122",
                    "178.32.181.98",
                    "81.170.217.107",
                    "91.200.85.68",
                    "198.23.187.158",
                    "219.79.6.122",
                    "5.9.212.206",
                    "66.31.208.246",
                    "198.98.49.3",
                    "77.131.37.239",
                    "85.127.92.85",
                    "83.240.119.176",
                    "88.149.244.127",
                    "84.200.77.243",
                    "192.42.116.161",
                    "188.138.121.118",
                    "76.28.234.23",
                    "216.17.99.144",
                    "109.169.0.29",
                    "71.95.40.252",
                    "38.229.79.2",
                    "122.196.178.87",
                    "23.95.39.161",
                    "178.201.171.116",
                    "92.222.4.178",
                    "153.121.56.221",
                    "192.34.59.48",
                    "178.21.114.69",
                    "81.20.132.158",
                    "104.131.231.241",
                    "212.64.32.68",
                    "54.166.25.44",
                    "93.220.100.16",
                    "178.62.77.182",
                    "69.90.151.229",
                    "178.167.85.210",
                    "84.183.90.241",
                    "212.83.162.152",
                    "173.74.56.217",
                    "212.83.158.20",
                    "91.145.118.53",
                    "82.234.141.197",
                    "5.167.42.101",
                    "107.161.81.187",
                    "79.136.29.43",
                    "46.252.209.63",
                    "91.121.133.195",
                    "95.211.175.250"

                    ]
                _.map ips, env.trace
            env.gogo = ->
                ips = [ "95.90.115.64",
                        "95.91.131.182",
                        "95.97.160.204",
                        "96.126.102.136",
                        "96.126.105.219",
                        "96.126.110.60",
                        "96.126.110.60",
                        "96.126.118.227",
                        "96.126.122.166",
                        "96.126.127.88",
                        "96.126.96.9",
                        "96.126.96.90",
                        "96.19.144.198",
                        "96.226.109.5",
                        "96.226.156.72",
                        "96.227.111.250",
                        "96.229.50.151",
                        "96.230.24.196",
                        "96.232.87.66",
                        "96.238.35.180",
                        "96.238.5.111",
                        "96.242.128.99",
                        "96.248.215.63",
                        "96.253.78.107",
                        "96.255.133.41",
                        "96.255.71.201",
                        "96.255.93.57",
                        "96.28.189.94",
                        "96.31.67.15",
                        "96.33.6.135",
                        "96.35.130.131",
                        "96.37.60.63",
                        "96.40.41.45",
                        "96.41.113.140",
                        "96.42.33.27",
                        "96.43.129.35",
                        "96.44.189.100",
                        "96.44.189.101",
                        "96.44.189.102",
                        "96.47.226.20",
                        "96.47.226.21",
                        "96.47.226.22",
                        "96.47.65.26",
                        "96.49.12.153",
                        "96.52.160.241",
                        "96.52.17.105",
                        "97.101.200.122",
                        "97.102.74.194",
                        "97.102.79.14",
                        "97.107.131.163",
                        "97.107.132.24",
                        "97.107.134.127",
                        "97.107.138.68",
                        "97.107.139.108",
                        "97.107.139.189",
                        "97.107.139.28",
                        "97.107.142.218",
                        "97.107.142.218",
                        "97.107.142.234",
                        "97.118.30.36",
                        "97.85.167.70",
                        "97.87.61.64",
                        "97.93.31.185",
                        "97.95.32.178",
                        "98.101.56.178",
                        "98.109.117.17",
                        "98.109.129.173",
                        "98.109.75.240",
                        "98.112.179.67",
                        "98.113.21.153",
                        "98.116.223.129",
                        "98.124.116.198",
                        "98.142.47.54",
                        "98.150.223.221",
                        "98.17.117.1",
                        "98.180.55.74",
                        "98.183.144.247",
                        "98.193.197.74",
                        "98.196.100.29",
                        "98.199.116.208",
                        "98.201.146.23",
                        "98.201.37.191",
                        "98.206.180.112",
                        "98.206.182.78",
                        "98.210.164.198",
                        "98.214.243.85",
                        "98.216.168.108",
                        "98.217.157.76",
                        "98.218.50.130",
                        "98.218.55.47",
                        "98.219.31.86",
                        "98.221.48.12",
                        "98.224.218.238",
                        "98.231.137.94",
                        "98.24.24.19",
                        "98.24.84.150",
                        "98.245.167.204",
                        "98.245.213.97",
                        "98.246.44.224",
                        "98.248.29.233",
                        "98.252.141.107",
                        "98.255.201.171",
                        "100.36.184.230",
                        "100.37.104.28",
                        "100.8.97.205",
                        "101.99.64.150",
                        "103.10.197.50",
                        "103.10.199.100",
                        "103.16.26.71",
                        "103.240.91.7",
                        "103.25.56.16",
                        "103.250.184.149",
                        "103.41.132.53",
                        "103.6.213.198",
                        "104.128.171.62",
                        "104.128.228.41",
                        "104.128.78.107",
                        "104.128.78.107",
                        "104.128.78.108",
                        "104.128.78.108",
                        "104.131.106.181",
                        "104.131.108.7",
                        "104.131.110.213",
                        "104.131.114.43",
                        "104.131.114.72",
                        "104.131.117.231",
                        "104.131.12.139",
                        "104.131.123.16",
                        "104.131.129.130",
                        "104.131.129.30",
                        "104.131.134.47",
                        "104.131.154.252",
                        "104.131.16.241",
                        "104.131.166.243",
                        "104.131.172.46",
                        "104.131.19.119",
                        "104.131.204.147",
                        "104.131.206.23"

                        ]
                _.map ips, (ip) ->
                    env.ping ip            
            
            pingdata = []
            
            env.ping = (host) =>
                env.lweb.query { ping: host }, (msg) =>
            
                    if not msg?.loc then return
                    pingdata.push msg

            env.drawPing = ->
                bubbles = _.map pingdata, (entry) ->
                    entry = 
                        name: "ip: #{entry.ip}<br>hostname: #{entry.hostname}<br>city: #{entry.city}<br>ping: #{entry.ping}"
                        radius: 5
                        yeild: 15000
                        defaultFillColor: 'green',
                        borderWidth: 1,
                        borderColor: "rgba(#{entry.ping},#{255 - entry.ping},0,1)",
                        popupOnHover: true,
                        fillOpacity: 0.2,
                        fill: "rgb(#{entry.ping},#{255 - entry.ping},0)",
                        highlightOnHover: false,
                        highlightFillColor: 'green',
                        highlightBorderColor: 'rgba(250, 15, 160, 0.2)',
                        highlightBorderWidth: 2,
                        highlightFillOpacity: 0.85
                        latitude: entry.loc.latitude
                        longitude: entry.loc.longitude
                    [ entry.x, entry.y ] = map.latLngToXY(entry.latitude, entry.longitude)

                    entry

                distance = (entry1, entry2) ->
                    Math.abs(entry1.x - entry2.x) + Math.abs(entry1.y - entry2.y)

                bubbles = _.map bubbles, (entry) =>
                    r = _.reduce bubbles, ((radius,entryCompare) ->
                        if entry is entryCompare then return radius
                        if (d = distance(entry, entryCompare)) < radius then return d
                        else return radius
                        ), 200

                    if (entry.radius = Math.round(r / 2)) < 7 then entry.radius = 7
#                    entry.radius = 8
                    entry

                console.log bubbles
                window.bubbles = bubbles
                map.bubbles bubbles

                               
            #parseSample = -> require('./parseSample').f(map)
            #parseSample()
            bubbles = []                                                
            env.trace = (host) =>
                oldloc = undefined

                env.lweb.query { trace: host }, (msg) =>
                    
                    if not msg?.loc then return
                    if msg.ping > 255 then msg.ping = 250
                    bubble = 
                        name: "ip: #{msg.ip}<br>hostname: #{msg.hostname}<br>city: #{msg.city}<br>ping: #{msg.ping}ms"
                        radius: 5
                        yeild: 15000
                        defaultFillColor: 'green',
                        borderWidth: 1,
                        borderColor: "rgba(255,0,0,1)",
                        popupOnHover: true,
                        fillOpacity: 0.2,
                        fill: "rgba(255,0,0,0.7)",
                        highlightOnHover: false,
                        highlightFillColor: 'green',
                        highlightBorderColor: 'rgba(250, 15, 160, 0.2)',
                        highlightBorderWidth: 2,
                        highlightFillOpacity: 0.85
                        latitude: msg.loc.latitude
                        longitude: msg.loc.longitude
                        
                    bubbles.push bubble
                    
                    if not oldloc then oldloc = msg; return
                    options =
                        strokeWidth: 1
                        strokeColor: 'rgba(255,0,0,0.5)'
                        #greatArc: true
                        arcSharpness: 10

                    if oldloc.vpn then options.strokeColor = 'rgba(0,255,0,0.5)'

                    arcs.push arc =
                        origin: oldloc.loc,
                        destination: msg.loc
                        options: options

                    console.log bubbles
                    @map.bubbles bubbles
                    @map.arc arcs
                    oldloc = msg
                    
            window.addEventListener 'resize', =>
                @$el.height $(window).height()
                @map.resize();
            @

    defineView "presenceEntry", template: require('./ejs/presenceEntry.ejs'), nohook: true,
        render: -> @
    
    callback()