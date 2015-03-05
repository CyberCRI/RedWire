# Get alias for the global scope
globals = @

# All will be in the "RW" namespace
RW = globals.RW ? {}
globals.RW = RW

RW.io = {}

# Define keyboard input io
RW.io.keyboard = 
  meta:
    visual: false
  factory: (options) ->
    eventNamespace = _.uniqueId('keyboard')

    keysDown = {}

    $(options.elementSelector).on "keydown.#{eventNamespace} keyup.#{eventNamespace} focusout.#{eventNamespace}", "#captureSpace", (event) ->
      event.preventDefault()   

      # jQuery standardizes the keycode into http://api.jquery.com/event.which/
      switch event.type 
        when 'keydown' then keysDown[event.which] = true
        when 'keyup' then delete keysDown[event.which]
        when 'focusout' then keysDown = {} # Lost focus, so will not receive keyup events
        else throw new Error('Unexpected event type')

    return {
      provideData: -> 
        global: 
          keysDown: keysDown

      establishData: -> # NOOP. Input io does not take data

      # Remove all event handlers
      destroy: -> $(options.elementSelector).off(".#{eventNamespace}")
    }

# Define mouse input/output io
RW.io.mouse = 
  meta:
    visual: false
  factory: (options) ->
    eventNamespace = _.uniqueId('mouse')

    mouse =
      down: false
      position: [0, 0]
      cursor: null
    lastMouse = RW.cloneData(mouse)

    # This disables selection, which allows the cursor to change in Chrome
    $(options.elementSelector).on("selectstart.#{eventNamespace}", -> false)

    $(options.elementSelector).on "mousedown.#{eventNamespace} mouseup.#{eventNamespace} mousemove.#{eventNamespace} mouseleave.#{eventNamespace}", "#captureSpace", (event) ->
      switch event.type 
        when 'mousedown' then mouse.down = true
        when 'mouseup' then mouse.down = false
        when 'mousemove'
          # Get position relative to canvas.
          # Based on http://www.html5canvastutorials.com/advanced/html5-canvas-mouse-coordinates/
          rect = event.target.getBoundingClientRect()
          target = $(event.target)
          mouse.position = [
            Math.floor((event.clientX - rect.left) * target.attr("width") / rect.width)
            Math.floor((event.clientY - rect.top) * target.attr("height") / rect.height)
          ]

    return {
      provideData: -> 
        # Calculate justDown and justUp in terms of previous data
        info = 
          down: mouse.down
          position: mouse.position
          cursor: mouse.cursor
          justDown: mouse.down and not lastMouse.down
          justUp: not mouse.down and lastMouse.down
        lastMouse = RW.cloneData(mouse)
        return {
          global:
            info
          }

      establishData: (data) -> 
        # TODO: how to handle contention for cursor across circuits?
        cursor = ""
        for circuitId, circuitData of data
          cursor = circuitData.cursor || cursor
        $(options.elementSelector).css("cursor", cursor)

      # Remove all event handlers
      destroy: -> $(options.elementSelector).off(".#{eventNamespace}")
    }

# Define canvas output io
RW.io.canvas =  
  meta:
    visual: true
  factory: (options) ->
    CANVAS_CSS = "position: absolute; left: 0px; top: 0px; pointer-events: none;"

    makeLayerId = (circuitId, layerName) -> "#{circuitId}.#{layerName}"
    deconstructLayerId = (layerId) -> layerId.split(".")

    createLayers = ->
      # Convert layers to ordered
      createdLayers = {}
      for { circuitId, name, depth } in options.layers
        layerId = makeLayerId(circuitId, name)
        layer = $("<canvas id='canvasLayer-#{layerId}' class='gameCanvas' width='#{options.size[0]}' height='#{options.size[1]}' style='z-index: #{depth}; #{CANVAS_CSS}' />")
        $(options.elementSelector).append(layer)
        createdLayers[layerId] = layer

      return createdLayers

    # Default 
    orderForShape = (shape) -> return shape.order || 0

    shapeSorter = (a, b) -> return orderForShape(a) - orderForShape(b)

    interpretStyle = (style, ctx) ->
      if _.isString(style) then return style
      if not _.isObject(style) then throw new Error('Style must be string or object')

      switch style.type
        when 'radialGradient'
          grad = ctx.createRadialGradient(style.start.position[0], style.start.position[1], style.start.radius, style.end.position[0], style.end.position[1], style.end.radius)
          for colorStop in style.colorStops
            grad.addColorStop(colorStop.position, colorStop.color)
          return grad
        when 'linearGradient'
          grad = ctx.createLinearGradient(style.startPosition[0], style.startPosition[1], style.endPosition[0], style.endPosition[1])
          for colorStop in style.colorStops
            grad.addColorStop(colorStop.position, colorStop.color)
          return grad
        else throw new Error('Unknown or missing style type')

    handleTransformations = (shape, ctx) ->
      # Not sure this is done in the right order
      if shape.translation? 
        ctx.translate(shape.translation[0], shape.translation[1])
        if not shape.position? then shape.position = [0, 0]
      if shape.rotation? then ctx.rotate(shape.rotation * Math.PI / 180) # Convert to radians
      if shape.scale? 
        if _.isArray(shape.scale) then ctx.scale(shape.scale[0], shape.scale[1])
        else if _.isNumber(shape.scale) then ctx.scale(shape.scale, shape.scale)
        else throw new Error('Scale argument must be number or array')

    drawShape = (shape, ctx, assets) ->
      # TODO: verify that arguments are of the correct type (the canvas API will not complain, just misfunction!)
      ctx.save()
      handleTransformations(shape, ctx)
      if shape.composition then ctx.globalCompositeOperation = shape.composition
      if shape.alpha then ctx.globalAlpha = shape.alpha

      switch shape.type
        when 'rectangle' 
          # Fill in defaults
          if "fillStyle" not of shape and "strokeStyle" not of shape then shape.fillStyle = "#cf0404"
          _.defaults shape, 
            size: [100, 100]
            position: [100, 100]

          if shape.fillStyle
            ctx.fillStyle = interpretStyle(shape.fillStyle, ctx)
            ctx.fillRect(shape.position[0], shape.position[1], shape.size[0], shape.size[1])
          if shape.strokeStyle
            ctx.strokeStyle = interpretStyle(shape.strokeStyle, ctx)
            if shape.lineWidth then ctx.lineWidth = shape.lineWidth
            ctx.strokeRect(shape.position[0], shape.position[1], shape.size[0], shape.size[1])
        when 'image'
          if shape.asset not of assets then throw new Error("Cannot find asset '#{shape.asset}' for shape '#{JSON.stringify(shape)}'")

          # Fill in defaults
          if "position" not of shape then shape.position = [100, 100]

          img = assets[shape.asset]
          size = if shape.size
              # Clamp size to image size
              [Math.min(shape.size[0], img.naturalWidth), Math.min(shape.size[1], img.naturalHeight)]
            else 
              [img.naturalWidth, img.naturalHeight]
          offset = shape.offset || [0, 0]
          try 
            # drawImage(image, sx, sy, sw, sh, dx, dy, dw, dh)
            ctx.drawImage(img, offset[0], offset[1], size[0], size[1], shape.position[0], shape.position[1], size[0], size[1])
          catch error
            throw new Error("Error drawing image shape #{JSON.stringify(shape)}: #{RW.formatStackTrace(error)}")
        when 'text'
          # Fill in defaults
          if "fillStyle" not of shape and "strokeStyle" not of shape then shape.fillStyle = "#cf0404"
          _.defaults shape, 
            position: [200, 200]
            text: "RedWire"
            font: "40px Courier New"
            align: "left"

          text = _.isString(shape.text) && shape.text || JSON.stringify(shape.text)
          ctx.font = shape.font
          ctx.textAlign = shape.align
          if shape.fillStyle
            ctx.fillStyle = interpretStyle(shape.fillStyle, ctx)
            ctx.fillText(text, shape.position[0], shape.position[1])
          if shape.strokeStyle
            ctx.strokeStyle = interpretStyle(shape.strokeStyle, ctx)
            ctx.strokeText(text, shape.position[0], shape.position[1])
        when 'path'
          # Fill in defaults
          if "fillStyle" not of shape and "strokeStyle" not of shape then shape.strokeStyle = "#cf0404"
          _.defaults shape, 
            points: [ [200, 200], [400, 200], [300, 100] ]
            lineWidth: 10

          ctx.beginPath()
          ctx.moveTo(shape.points[0][0], shape.points[0][1])
          for point in shape.points[1..] then ctx.lineTo(point[0], point[1])
          if shape.fillStyle
            ctx.fillStyle = interpretStyle(shape.fillStyle, ctx)
            ctx.fill()
          if shape.strokeStyle
            ctx.strokeStyle = interpretStyle(shape.strokeStyle, ctx)
            if shape.lineWidth then ctx.lineWidth = shape.lineWidth
            if shape.lineCap then ctx.lineCap = shape.lineCap
            if shape.lineJoin then ctx.lineJoin = shape.lineJoin
            if shape.miterLimit then ctx.miterLimit = shape.miterLimit
            ctx.stroke()
        when 'circle'
          # Fill in defaults
          if "fillStyle" not of shape and "strokeStyle" not of shape then shape.fillStyle = "#cf0404"
          _.defaults shape, 
            position: [300, 300]
            radius: 50

          ctx.beginPath();
          ctx.moveTo(shape.position[0], shape.position[1])
          ctx.arc(shape.position[0], shape.position[1], shape.radius, 0, 2 * Math.PI)
          if shape.fillStyle
            ctx.fillStyle = interpretStyle(shape.fillStyle, ctx)
            ctx.fill()
          if shape.strokeStyle
            ctx.strokeStyle = interpretStyle(shape.strokeStyle, ctx)
            if shape.lineWidth then ctx.lineWidth = shape.lineWidth
            ctx.stroke()
        else throw new Error('Unknown or missing shape type')
      ctx.restore()

    layers = createLayers()

    return {
      provideData: -> 
        # Return a global size, as well as an empty object of shapes for each layer per circuit
        data = 
          global:
            size: options.size
        for circuitMeta in options.circuitMetas
          data[circuitMeta.id] = 
            size: options.size
        for layer in options.layers
          data[layer.circuitId][layer.name] = []
        return data

      establishData: (data) -> 
        # Clear layers 
        for layerId, canvas of layers
          canvas[0].getContext('2d').clearRect(0, 0, options.size[0], options.size[1])

        # For each layer, sort shapes and then draw them
        for circuitId, circuitData of data
          circuitType = _.findWhere(options.circuitMetas, { id: circuitId })?.type
          if not circuitType? then continue # Recorded data with circuits can trip us up

          for layerName, shapeArray of circuitData when layerName isnt "size"
            layerId = makeLayerId(circuitId, layerName)
            if layerId not of layers then throw new Error("Invalid layer '#{layerName}' in circuit '#{circuitId}'")

            shapeArray.sort(shapeSorter)

            ctx = layers[layerId][0].getContext('2d')
            for shape in shapeArray then drawShape(shape, ctx, options.assets)

        return null # avoid accumulating results

      destroy: -> 
        for layerId, canvas of layers then canvas.remove()
    }

# Define html input io
RW.io.html =  
  meta:
    visual: true
  factory: (options) ->
    state = RW.mapToObject _.pluck(options.circuitMetas, "id"), ->
      templates: {}
      layers: {}
      views: {}
      callbacks: {}

    codeTemplateId = (circuitId, templateName) -> return "#{circuitId}.#{templateName}"
    decodeTemplateId = (templateId) -> templateId.split(".")

    rivets.configure
      handler: (target, event, binding) ->
        # binding.view.models.data will give the id of the template
        [circuitId, templateName] = decodeTemplateId(binding.view.models.data)
        state[circuitId].templates[templateName].values[binding.keypath] = true

      adapter: 
        subscribe: (templateId, keypath, callback) -> 
          # console.log("subscribe called with ", arguments)
          [circuitId, templateName] = decodeTemplateId(templateId) 
          state[circuitId].callbacks[templateName][keypath] = callback
        unsubscribe: (templateId, keypath, callback) ->
          # console.log("unsubscribe called with ", arguments)
          [circuitId, templateName] = decodeTemplateId(templateId) 
          delete state[circuitId].callbacks[templateName][keypath]
        read: (templateId, keypath) ->
          # console.log("read called with ", arguments)
          [circuitId, templateName] = decodeTemplateId(templateId) 
          return state[circuitId].templates[templateName].values[keypath]
        publish: (templateId, keypath, value) ->
          # console.log("publish called with ", arguments)
          [circuitId, templateName] = decodeTemplateId(templateId) 
          state[circuitId].templates[templateName].values[keypath] = value

    return {
      provideData: -> 
        result = RW.mapToObject _.pluck(options.circuitMetas, "id"), (circuitId) -> 
          state[circuitId].templates
        result.global = {}
        return result

      establishData: (data) -> 
        for circuitId, circuitData of data
          # circuitData are in the template of { templateName: { asset: "", initialValues: { ... } values: { name: value, ... }, ... }, ...}
          existingTemplates = _.keys(state[circuitId].templates)
          newTemplates = _.keys(circuitData)

          # Remove all templates that are no longer to be shown
          for templateName in _.difference(existingTemplates, newTemplates) 
            delete state[circuitId].templates[templateName]
            state[circuitId].layers[templateName].remove()
            delete state[circuitId].layers[templateName]
            state[circuitId].views[templateName].unbind()
            delete state[circuitId].views[templateName]
            delete state[circuitId].callbacks[templateName]

          # Add new templates 
          for templateName in _.difference(newTemplates, existingTemplates) 
            # Create template
            templateHtml = options.assets[circuitData[templateName].asset]
            # TODO: create all layers before hand?
            layerOptions = _.findWhere(options.layers, { circuitId: circuitId, name: templateName })
            
            # Find out what the depth is
            layer = _.findWhere options.layers, 
              "circuitId": circuitId
              "name": templateName
            if not layer then throw new Error("Invalid HTML layer '#{templateName}' in circuit '#{circuitId}'")

            outerWrapper = $("<div id='html-#{circuitId}-#{templateName}' style='position: absolute; z-index: #{layer.depth}; pointer-events: none; width: #{options.size[0]}px; height: #{options.size[1]}px'/>")
            outerWrapper.append(templateHtml)
            $(options.elementSelector).append(outerWrapper)
            state[circuitId].layers[templateName] = outerWrapper

            # Copy over template data to state
            state[circuitId].templates[templateName] = circuitData[templateName] 

            # Setup initial values if available
            state[circuitId].templates[templateName].values = _.defaults({}, circuitData[templateName].values, circuitData[templateName].initialValues)

            # Bind to the template name
            state[circuitId].callbacks[templateName] = { } # Will be filled by calls to adapter.subscribe()
            state[circuitId].views[templateName] = rivets.bind(outerWrapper[0], { data: codeTemplateId(circuitId, templateName) })

          # Update existing templates with new circuitData
          for templateName in _.intersection(newTemplates, existingTemplates) 
            # Start with current values
            newValues = RW.cloneData(state[circuitId].templates[templateName].values)

            # Overwrite old state with new 
            if circuitData[templateName].values? 
              newValues = circuitData[templateName].values

            # Overwrite only selected properties with new values 
            if circuitData[templateName].overwriteValues? 
              _.extend(newValues, circuitData[templateName].overwriteValues)

            # TODO: call individual binders instead of syncronizing the whole model?
            #   for key in _.union(_.keys(circuitData[templateName].values), _.keys(templates[templateName].values)
            if not _.isEqual(newValues, state[circuitId].templates[templateName].values)
              # Overwrite values in the state with those established 
              state[circuitId].templates[templateName].values = newValues
              state[circuitId].views[templateName].sync() 

          # Reset all event bindings to false
          for templateName, view of state[circuitId].views
            for binding in view.bindings
              if binding.type.indexOf("on-") == 0
                state[circuitId].templates[templateName].values[binding.keypath] = false

        return null

      # Remove all event handlers
      destroy: -> 
        for circuitId, circuitState of state
          for templateName, view of circuitState.views
            view.unbind()
          for templateName, layer of circuitState.layers
            layer.remove()
    }

# Define time io, that provides the current time in ms
RW.io.time =  
  meta:
    visual: false
  factory: (options) ->
    provideData: -> 
      global: Date.now()
    establishData: -> # NOP
    destroy: -> # NOP

# The HTTP io makes AJAX requests 
RW.io.http =  
  meta:
    visual: false
  factory: (options) ->
    state = RW.mapToObject _.pluck(options.circuitMetas, "id"), -> 
      requests: {}
      responses: {}

    io =
      provideData: -> _.extend({}, state, global: { requests: {}, responses: {} }) 

      establishData: (ioData) -> 
        # Expecting a format like { requests: { id: { method:, url:, data:, cache:, contentType: }, ... }, { responses: { id: { code:, data: }, ... }

        for circuitId in _.pluck(options.circuitMetas, "id") 
          # Create new requests
          for requestName in _.difference(_.keys(ioData[circuitId].requests), _.keys(state[circuitId].requests)) 
            do (requestName) ->
              jqXhr = $.ajax 
                url: ioData[circuitId].requests[requestName].url
                type: ioData[circuitId].requests[requestName].method ? "GET"
                cache: ioData[circuitId].requests[requestName].cache ? true
                data: ioData[circuitId].requests[requestName].data
                contentType: ioData[circuitId].requests[requestName].contentType
              jqXhr.done (data, textStatus) -> 
                state[circuitId].responses[requestName] = 
                  status: textStatus
                  data: data
              jqXhr.fail (__, textStatus, errorThrown) -> 
                state[circuitId].responses[requestName] = 
                  status: textStatus
                  error: errorThrown

              delete state[circuitId].requests[requestName]

          # Remove deleted responses
          for requestName in _.difference(_.keys(state[circuitId].responses), _.keys(ioData[circuitId].responses)) 
            delete state[circuitId].responses[requestName]

        return state

      destroy: () -> # NOP

    return io

# Define chart output io
RW.io.charts =  
  meta:
    visual: true
  factory: (options) ->
    capitalizeFirstLetter = (str) -> str[0].toUpperCase() + str.slice(1)

    makeLayerId = (circuitId, layerName) -> "#{circuitId}.#{layerName}"
    deconstructLayerId = (layerId) -> layerId.split(".")

    createLayers = ->
      # Convert layers to ordered
      createdLayers = {}
      for { circuitId, name, depth } in options.layers
        layerId = makeLayerId(circuitId, name)
        
        # Create a canvas element 
        canvasProps = "id='chartLayer-#{layerId}' class='chartCanvas' tabIndex=0"
        canvasCss = "z-index: #{depth}; position: absolute;"
        canvas = $("<canvas #{canvasProps} style='#{canvasCss}' />")
        $(options.elementSelector).append(canvas)
        createdLayers[layerId] = canvas
      return createdLayers

    clearLayer = (circuitId, layerName) ->
      layer = layers[makeLayerId(circuitId, layerName)]
      context = layer[0].getContext("2d")
      context.clearRect(0, 0, layer[0].width, layer[0].height)

    removeChart = (circuitId, layerName) -> 
      clearLayer(circuitId, layerName)
      delete charts[circuitId][layerName]

    # Format { circuitId: { name: { canvas:, data: }}} 
    charts = RW.mapToObject(_.pluck(options.circuitMetas, "id"), -> {})
    layers = createLayers()

    return {
      provideData: -> 
        data = 
          global: {}
        for circuitMeta in options.circuitMetas
          data[circuitMeta.id] = {}
          for layer in options.layers
            data[layer.circuitId][layer.name] = null
        return data

      establishData: (ioData) -> 
        for circuitId, circuitData of ioData
          circuitType = _.findWhere(options.circuitMetas, { id: circuitId })?.type
          if not circuitType? then continue # Recorded data with circuits can trip us up

          # Remove unused charts
          for layerName in _.difference(_.keys(charts[circuitId]), _.keys(circuitData)) 
            removeChart(circuitId, chartName)

          # Create and update charts
          for layerName, chartData of circuitData 
            layerId = makeLayerId(circuitId, layerName)
            if layerId not of layers then throw new Error("Invalid layer '#{layerName}' in circuit '#{circuitId}'")

            # Expecting chartData like { size:, position:, data:, options: }}

            # If the chart already exists...
            if layerName of charts[circuitId] 
              #... and has the same data, don't bother redrawing it
              if _.isEqual(charts[circuitId][layerName].data, chartData) then continue
              # Otherwise remove it.
              else removeChart(circuitId, layerName)

            # If the chart is empty or null, remove it
            if not chartData then continue

            # Check it's a valid chart type
            chartType = chartData.type || "Line" 
            if chartType not of Chart.types 
              throw new Error("Unknown chart type: '#{chartData.type}'")

            # Define options
            displayOptions = 
              size: chartData.size ? options.size
              position: chartData.position ? [0, 0]
            chartOptions = _.defaults chartData.options ? {},
              animation: false
              showTooltips: false

            # Retrieve the existing canvas layer, then set its position and size
            layer = layers[layerId]
            layer.prop
              width: displayOptions.size[0]
              height: displayOptions.size[1] 
            layer.css 
              left: "#{displayOptions.position[0]}px"
              top: "#{displayOptions.position[1]}px"

            # Create a new Chart object
            chart = new Chart(layer[0].getContext("2d"))

            # Call the correct method on it
            chart[capitalizeFirstLetter(chartType)](chartData.data, chartOptions)

            # Store it
            charts[circuitId][layerName] = 
              chart: chart
              data: chartData

          return null

      destroy: -> 
        for circuitId, circuitCharts of charts
          for layerName, chart of circuitCharts then clearLayer(circuitId, layerName)
        $(".chartCanvas").remove()
        return null
    }


# Define audio output io
RW.io.sound =  
  meta: 
    audio: true
  factory: (options) ->

    makeChannelId = (circuitId, channelName) -> "#{circuitId}.#{channelName}"
    deconstructLayerId = (channelId) -> channelId.split(".")

    stopPlayingSounds = ->
      for id, source of playingSourceNodes
        source.stop()

    # Returns a unique id of the sound clip in playingSourceNodes
    connectAndPlayBuffer = (buffer, shouldLoop = false) ->
      # Create source node
      source = RW.audioContext.createBufferSource()
      source.buffer = buffer
      source.connect(RW.lineOut.destination)
      source.loop = shouldLoop

      # Keep track of what sounds are playing
      id = _.uniqueId()
      source.onended = -> delete playingSourceNodes[id]
      playingSourceNodes[id] = source

      # Play immediately
      source.start(0)
      return id

    playingMusic = {}

    # maps asset names to AudioBufferSourceNode objects
    playingSourceNodes = {}

    inPlaySequence = false

    return {
      enterPlaySequence: ->
        inPlaySequence = true

        # startup playing music
        for channelId, playingMusicData of playingMusic
          if playingMusicData.channelData.asset then connectAndPlayBuffer(options.assets[playingMusicData.channelData.asset], true)

      leavePlaySequence: ->
        stopPlayingSounds()
        inPlaySequence = false

      provideData: -> 
        global: { } 

      establishData: (data) -> 
        # Only play sounds in "play" mode
        if not inPlaySequence then return 

        for circuitId, circuitData of data
          circuitType = _.findWhere(options.circuitMetas, { id: circuitId }).type

          for channelName, channelData of circuitData
            channelMeta = _.findWhere(options.channels, { circuitId: circuitId, name: channelName })
            if not channelMeta? then throw new Error("Cannot find channel '#{channelName}' for circuit '#{circuitId}'") 

            switch channelMeta.type
              when "clip" 
                for sound in channelData
                  if sound.asset not of options.assets 
                    throw new Error("Cannot find asset '#{sound.asset}' for circuit '#{circuitId}'")

                  connectAndPlayBuffer(options.assets[sound.asset])
              when "music" 
                # Channel data should be like { asset: "qsdf" } or null
                channelId = makeChannelId(circuitId, channelName)
                if _.isEqual(playingMusic[channelId]?.channelData, channelData) then continue

                # Stop music if its playing
                # TODO: handle volume changes of same music
                if playingMusic[channelId]
                  playingSourceNodes[playingMusic[channelId].id].stop()

                # Play new music
                if channelData
                  if channelData.asset not of options.assets 
                    throw new Error("Cannot find asset '#{channelData.asset}' for circuit '#{circuitId}'")

                  # TODO: handle crossfading
                  sourceId = connectAndPlayBuffer(options.assets[channelData.asset], true)

                playingMusic[channelId] = 
                  channelData: channelData
                  id: sourceId
              when "fx"
                for sound in channelData
                  _.defaults sound, 
                    fx: ["square",0.0000,0.4000,0.0000,0.3200,0.0000,0.2780,20.0000,496.0000,2400.0000,0.4640,0.0000,0.0000,0.0100,0.0003,0.0000,0.0000,0.0000,0.0235,0.0000,0.0000,0.0000,0.0000,1.0000,0.0000,0.0000,0.0000,0.0000] 
                  buffer = WebAudiox.getBufferFromJsfx(RW.audioContext, sound.fx)
                  connectAndPlayBuffer(buffer)
              else 
                throw new Error("Unknown channel type '#{channelMeta.type}'")

        return null # avoid accumulating results

      destroy: -> stopPlayingSounds()
    }

# A RedMetrics IO service to send game analytics data 
RW.io.metrics =  
  meta:
    visual: false
  factory: (options) ->
    SNAPSHOT_FRAME_DELAY = 60 # Only record a snapshot every 60 frames

    eventQueue = []
    snapshotQueue = []
    timerId = null
    playerId = null
    playerInfo = {} # Current state of player 
    snapshotFrameCounter = 0 ## Number of frames since last snapshot

    configIsValid = -> options.metrics and options.metrics.gameVersionId and options.metrics.host 

    sendResults = ->
      sendEvents()
      sendSnapshots()

    sendEvents = ->
      if eventQueue.length is 0 then return 

      # Send AJAX request
      jqXhr = $.ajax 
        url: options.metrics.host + "/v1/event/" 
        type: "POST"
        data: JSON.stringify(eventQueue)
        processData: false
        contentType: "application/json"

      # Clear queue
      eventQueue = []

    sendSnapshots = ->
      if snapshotQueue.length is 0 then return 

      # Send AJAX request
      jqXhr = $.ajax 
        url: options.metrics.host + "/v1/snapshot/" 
        type: "POST"
        data: JSON.stringify(snapshotQueue)
        processData: false
        contentType: "application/json"

      # Clear queue
      snapshotQueue = []

    io =
      enterPlaySequence: ->
        if not configIsValid() then return 

        # Reset snapshot counter so that it will be sent on the first frame
        snapshotFrameCounter = SNAPSHOT_FRAME_DELAY

        # Create player
        jqXhr = $.ajax 
          url: options.metrics.host + "/v1/player/"
          type: "POST"
          data: "{}"
          processData: false
          contentType: "application/json"
        jqXhr.done (data, textStatus) -> 
          playerId = data.id
          # Start sending events
          timerId = window.setInterval(sendResults, 5000)
        jqXhr.fail (__, textStatus, errorThrown) -> 
          throw new Error("Cannot create player: #{errorThrown}")
 
      leavePlaySequence: -> 
        # If metrics session was not created then ignore
        if not playerId then return

        # Send last data before stopping 
        sendResults()

        # Stop sending events
        window.clearInterval(timerId)
        playerId = null

      provideData: -> 
        global: 
          events: []
          player: playerInfo

      establishData: (ioData, additionalData) -> 
        # Only send data in play sequence
        if not playerId then return 

        # Contains updated playerInfo if necessary
        newPlayerInfo = null
        userTime = new Date().toISOString()

        # Expecting a format like { player: {}, events: [ type: "", section: [], coordinates: [], customData: }, ... ] }
        for circuitId in _.pluck(options.circuitMetas, "id") 
          # Collate all data into the events queue (disregard individual circuits)

          # Set game version and player IDs on events
          for event in ioData[circuitId].events
            eventQueue.push _.extend event, 
              gameVersion: options.metrics.gameVersionId
              player: playerId
              userTime: userTime

          if snapshotFrameCounter++ >= SNAPSHOT_FRAME_DELAY
            # Reset snapshot counter
            snapshotFrameCounter = 0

            # Send input memory and input IO data as snapshots
            snapshotQueue.push 
              gameVersion: options.metrics.gameVersionId
              player: playerId
              userTime: userTime
              customData:
                inputIo: additionalData.inputIoData
                memory: additionalData.memoryData

          # Update player info
          if not _.isEqual(ioData[circuitId].player, playerInfo) 
            newPlayerInfo = ioData[circuitId].player

        # Update player info if necessary
        if newPlayerInfo
          jqXhr = $.ajax 
            url: options.metrics.host + "/v1/player/" + playerId
            type: "PUT"
            data: JSON.stringify(newPlayerInfo)
            processData: false
            contentType: "application/json"
          playerInfo = newPlayerInfo

        return null # avoid accumulating results

      destroy: -> # NOP

    return io

