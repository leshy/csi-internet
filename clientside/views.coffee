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
                    defaultFill: "#2C2C43"
                    red: 'red'
                    
                fillOpacity:0.5

                geographyConfig: 
                    hideAntarctica: true
                    borderWidth: 1
                    borderColor: "#585886"
                
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
                            '1.0': '#00FF00' }
                else heatMap = @_heatMap
                    
                heatMap.setData max:0, data: []
                max = 0
                _.each data, (entry) =>
                    if not entry.val then return

                    [ entry.x, entry.y ] = @latLngToXY(entry.latitude, entry.longitude)
                    
                    if entry.val > max
                        max = entry.val
                        heatMap.setDataMax(max)

                    heatMap.addData(entry)
                
                console.log max
                                                            
            arcs = []
            bubbles = []
            heatz = []

            env.gogo = ->
                ips = [ "199.27.128.1", "173.245.48.1", "103.21.244.1", "103.22.200.1", "103.31.4.1", "141.101.64.1", "108.162.192.1", "190.93.240.1", "188.114.96.1", "197.234.240.1", "198.41.128.1", "162.158.0.1", "104.16.0.1", "172.64.0.1" ]
                _.map ips, (ip) ->
                    env.trace ip
                    
            env.trace = (host) =>
                oldloc = undefined
                
                env.lweb.query { trace: host }, (msg) =>
                    
                    if not msg?.loc then return

                    bubble = 
                        name: "ip: #{msg.ip}<br>hostname: #{msg.hostname}<br>city: #{msg.city}"
                        radius: 5
                        yeild: 15000
                        fillKey: 'red'
                        borderWidth: 1,
                        borderColor: 'rgba(0,255,0,1)',
                        popupOnHover: true,
                        fillOpacity: 0,
                        highlightOnHover: true,
                        highlightFillColor: '#FC8D59',
                        highlightBorderColor: 'rgba(250, 15, 160, 0.2)',
                        highlightBorderWidth: 2,
                        highlightFillOpacity: 0.85

                    heat =
                        radius: 50
                        val: 1
                        
                    _.extend bubble, msg.loc
                    _.extend heat, msg.loc
                    
                    bubbles.push bubble
                    #heatz.push heat
                    
                    @map.bubbles bubbles
                    #@map.heatMap heatz
                    
                    if not oldloc then oldloc = msg; return
                    options =
                        strokeWidth: 1
                        strokeColor: 'rgba(255,255,255,1)'
                        greatArc: true
                        arcSharpness: 1.1


                    if oldloc.vpn then options.strokeColor = 'rgba(0,255,0,1)'
                        
                    arcs.push arc =
                        origin: oldloc.loc,
                        destination: msg.loc
                        options: options
                    oldloc = msg
                    @map.arc(arcs)
                
            window.addEventListener 'resize', =>
                @$el.height $(window).height()
                @map.resize();
            @

    defineView "presenceEntry", template: require('./ejs/presenceEntry.ejs'), nohook: true,
        render: -> @
    
    callback()