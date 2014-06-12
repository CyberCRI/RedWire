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
  factory: (options = {}) ->
    eventNamespace = _.uniqueId('keyboard')

    keysDown = {}

    $(options.elementSelector).on "keydown.#{eventNamespace} keyup.#{eventNamespace} focusout.#{eventNamespace}", "canvas", (event) ->
      event.preventDefault()   

      # jQuery standardizes the keycode into http://api.jquery.com/event.which/
      switch event.type 
        when 'keydown' then keysDown[event.which] = true
        when 'keyup' then delete keysDown[event.which]
        when 'focusout' then keysDown = {} # Lost focus, so will not receive keyup events
        else throw new Error('Unexpected event type')

    return {
      provideData: -> 
        result = { 'keysDown': keysDown }
        return RW.mapToObject(options.circuitIds, -> result)

      establishData: -> # NOOP. Input io does not take data

      # Remove all event handlers
      destroy: -> $(options.elementSelector).off(".#{eventNamespace}")
    }

# Define mouse input/output io
RW.io.mouse = 
  meta:
    visual: false
  factory: (options = {}) ->
    eventNamespace = _.uniqueId('mouse')

    mouse =
      down: false
      position: [0, 0]
      cursor: null
    lastMouse = RW.cloneData(mouse)

    # This disables selection, which allows the cursor to change in Chrome
    $(options.elementSelector).on("selectstart.#{eventNamespace}", -> false)

    $(options.elementSelector).on "mousedown.#{eventNamespace} mouseup.#{eventNamespace} mousemove.#{eventNamespace} mouseleave.#{eventNamespace}", "canvas", (event) ->
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

        return RW.mapToObject(options.circuitIds, -> info)

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
  factory: (options = {}) ->
    CANVAS_CSS = "position: absolute; left: 0px; top: 0px;"

    makeLayerId = (circuitId, layerName) -> "#{circuitId}.#{layerName}"

    createLayers = ->
      # Convert layers to ordered
      createdLayers = {}
      for { circuitId, name, depth } in options.layers
        layerId = makeLayerId(circuitId, name)
        layer = $("<canvas id='canvasLayer-#{layerId}' class='gameCanvas' width='#{options.size[0]}' height='#{options.size[1]}' tabIndex=0 style='z-index: #{depth}; #{CANVAS_CSS}' />")
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
      if shape.translation then ctx.translate(shape.translation[0], shape.translation[1])
      if shape.rotation then ctx.rotate(shape.rotation * Math.PI / 180) # Convert to radians
      if shape.scale 
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
          if shape.fillStyle
            ctx.fillStyle = interpretStyle(shape.fillStyle, ctx)
            ctx.fillRect(shape.position[0], shape.position[1], shape.size[0], shape.size[1])
          if shape.strokeStyle
            ctx.strokeStyle = interpretStyle(shape.strokeStyle, ctx)
            if shape.lineWidth then ctx.lineWidth = shape.lineWidth
            ctx.strokeRect(shape.position[0], shape.position[1], shape.size[0], shape.size[1])
        when 'image'
          if shape.asset not of assets then throw new Error("Cannot find asset '#{shape.asset}' for shape '#{JSON.stringify(shape)}'")
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
          ctx.beginPath();
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

    options = _.defaults options,
      layers: []

    layers = createLayers()

    return {
      provideData: -> 
        result =
          size: options.size
          shapes: {}
        return RW.mapToObject(options.circuitIds, -> result)

      establishData: (data, assets) -> 
        # Clear layers and create shapeArrays
        shapeArrays = {}
        for layerName, canvas of layers
          canvas[0].getContext('2d').clearRect(0, 0, options.size[0], options.size[1])
          shapeArrays[layerName] = []

        # Copy shapes from object into arrays based on their layer
        for circuitId, circuitData of data
          for id, shape of circuitData.shapes
            if not shape.layer then throw new Error("Missing layer for shape '#{JSON.stringify(shape)}'")
            layerId = makeLayerId(circuitId, shape.layer)
            if layerId not of layers then throw new Error("Invalid layer for shape '#{JSON.stringify(shape)}'")

            shapeArrays[layerId].push(shape)

        # For each layer, sort shapes and then draw them
        for layerName, shapeArray of shapeArrays
          shapeArray.sort(shapeSorter)

          ctx = layers[layerName][0].getContext('2d')
          for shape in shapeArray then drawShape(shape, ctx, assets[circuitId])

      destroy: -> 
        for layerName, canvas of layers then canvas.remove()
    }

# Define HTML input io
RW.io.html =  
  meta:
    visual: true
  factory: (options = {}) ->
    state = RW.mapToObject options.circuitIds, ->
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
          state[circuitId]/templates[templateId].values[keypath] = value

    return {
      provideData: -> 
        return RW.mapToObject options.circuitIds, (circuitId) -> 
          receive: state[circuitId].templates
          send: {}

      establishData: (data, assets) -> 
        for circuitId, circuitData of data
          newTemplateData = circuitData.send 

          # data.send and data.receive are in the template of { templateName: { asset: "", values: { name: value, ... }, ... }, ...}
          existingTemplates = _.keys(state[circuitId].templates)
          newTemplates = _.keys(newTemplateData)

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
            templateHtml = assets[circuitId][newTemplateData[templateName].asset]
            # TODO: create all layers before hand?
            layerOptions = _.findWhere(options.layers, { circuitId: circuitId, name: templateName })
            depth = layerOptions?.depth ? 100 # Default to 100
            outerWrapper = $("<div id='html-#{circuitId}-#{templateName}' style='position: absolute; z-index: #{depth}; pointer-events: none; width: #{options.size[0]}px; height: #{options.size[1]}px'/>")
            outerWrapper.append(templateHtml)
            $(options.elementSelector).append(outerWrapper)
            state[circuitId].layers[templateName] = outerWrapper

            # Create newTemplateData
            state[circuitId].templates[templateName] = newTemplateData[templateName] 
            # Bind to the template name
            state[circuitId].callbacks[templateName] = { } # Will be filled by calls to adapter.subscribe()
            state[circuitId].views[templateName] = rivets.bind(outerWrapper[0], { data: codeTemplateId(circuitId, templateName) })

          # Update existing templates with new newTemplateData
          for templateName in _.intersection(newTemplates, existingTemplates) 
            # TODO: call individual binders instead of syncronizing the whole model?
            #   for key in _.union(_.keys(newTemplateData[templateName].values), _.keys(templates[templateName].values)
            if not _.isEqual(newTemplateData[templateName].values, state[circuitId].templates[templateName].values)
              state[circuitId].templates[templateName].values = newTemplateData[templateName].values
              state[circuitId].views[templateName].sync() 

          # Reset all event bindings to false
          for templateName, view of state[circuitId].views
            for binding in view.bindings
              if binding.type.indexOf("on-") == 0
                state[circuitId].templates[templateName].values[binding.keypath] = false

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
  factory: (options = {}) ->
    provideData: -> 
      result = Date.now()
      return RW.mapToObject(options.circuitIds, -> result)
    establishData: -> # NOP
    destroy: -> # NOP

# The HTTP io makes AJAX requests 
RW.io.http =  
  meta:
    visual: false
  factory: (options = {}) ->
    state = RW.mapToObject options.circuitIds, -> 
      requests: {}
      responses: {}

    io =
      provideData: () -> return state

      establishData: (ioData, assets) -> 
        # Expecting a format like { requests: { id: { method:, url:, data:, cache:, contentType: }, ... }, { responses: { id: { code:, data: }, ... }

        for circuitId in options.circuitIds 
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
  factory: (options = {}) ->
    makeChartId = (circuitId, chartName) -> "#{circuitId}.#{chartName}"

    capitalizeFirstLetter = (str) -> str[0].toUpperCase() + str.slice(1)

    # Format { circuitId: { name: { canvas:, data: }}} 
    charts = RW.mapToObject(options.circuitIds, -> {})

    removeChart = (circuitId, chartId) ->
      charts[circuitId][chartId].canvas.remove()
      delete charts[circuitId][chartId]

    return {
      provideData: -> RW.mapToObject(options.circuitIds, -> {})

      establishData: (ioData, assets) -> 
        # Expecting ioData like { chartA: { size:, position:, depth:, data:, options: }}
        for circuitId in options.circuitIds
          # Remove old charts 
          for chartName in _.difference(_.keys(charts[circuitId]), _.keys(ioData[circuitId])) then removeChart(circuitId, chartName)

          # Create new charts and update old ones
          for chartName, chartData of ioData[circuitId]
            # If the chart already exists...
            if chartName of charts[circuitId] 
              #... and has the same data, don't bother redrawing it
              if _.isEqual(charts[circuitId][chartName].data, chartData) then continue
              # Otherwise remove it.
              else removeChart(circuitId, chartName)

            # Check it's a valid chart type
            if chartData.type not in ["line", "bar", "radar", "polar", "pie", "doughnut"] 
              throw new Error("Unknown chart type: '#{chartData.type}'")

            # Define options
            displayOptions = 
              size: chartData.size ? options.size
              position: chartData.position ? [0, 0]
              depth: chartData.depth ? 50
            chartOptions = _.defaults chartData.options ? {},
              animation: false

            # Create a canvas element 
            canvasProps = "id='chartLayer-#{circuitId}-#{chartName}' class='chartCanvas' width='#{displayOptions.size[0]}' height='#{displayOptions.size[1]}' tabIndex=0"
            canvasCss = "z-index: #{displayOptions.depth}; position: absolute; left: #{displayOptions.position[0]}px; top: #{displayOptions.position[1]}px;"
            canvas = $("<canvas #{canvasProps} style='#{canvasCss}' />")
            $(options.elementSelector).append(canvas)
            charts[circuitId][chartName] = 
              canvas: canvas
              data: chartData

            # Create a new Chart object
            chart = new Chart(canvas[0].getContext("2d"))

            # Call the correct method on it
            chart[capitalizeFirstLetter(chartData.type)](chartData.data, chartOptions)

      destroy: -> 
        for chartName, canvas of charts then canvas.remove()
    }
