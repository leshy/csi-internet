helpers = require 'helpers'

exports.f = (map) ->
    bubbles = ->        
        bubbles = _.map sample, (entry) ->
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

            entry.radius = Math.round(r / 2)
            entry
            
        map.bubbles bubbles
                                    
    heat = -> 
        map.heatMap window.heat = _.map sample, (entry) ->
            radius: 50
            val: entry.ping / 100
            latitude: entry.loc.latitude
            longitude: entry.loc.longitude

    bubbles()
#    heat()