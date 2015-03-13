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
            Datamap

            window.map = @map = new Datamap
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
                    
            arcs = []
            bubbles = []
            
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

                    _.extend bubble, msg.loc
                    bubbles.push bubble
                    @map.bubbles bubbles
                        
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