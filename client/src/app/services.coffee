# Get alias for the global scope
globals = @

# All will be in the "GE" namespace
GE = globals.GE ? {}
globals.GE = GE

GE.services = {}

# Define keyboard input service
GE.services.Keyboard = (options = {}) ->
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
    provideData: -> return { 'keysDown': keysDown }

    establishData: -> # NOOP. Input service does not take data

    # Remove all event handlers
    destroy: -> $(options.elementSelector).off(".#{eventNamespace}")
  }

# Define mouse input/output service
GE.services.Mouse = (options = {}) ->
  eventNamespace = _.uniqueId('mouse')

  mouse =
    down: false
    position: [0, 0]
    cursor: null

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
    provideData: -> return mouse

    establishData: (data) -> 
      $(options.elementSelector).css("cursor", data.cursor || "")

    # Remove all event handlers
    destroy: -> $(options.elementSelector).off(".#{eventNamespace}")
  }

# Define canvas output service
GE.services.Canvas = (options = {}) ->
  CANVAS_CSS = "position: absolute; left: 0px; top: 0px;"

  createLayers = ->
    # Convert layers to ordered
    createdLayers = {}
    zIndex = 0
    for layerName in options.layers
      layer = $("<canvas id='canvasLayer-#{layerName}' class='gameCanvas' width='#{options.size[0]}' height='#{options.size[1]}' tabIndex=0 style='z-index: #{zIndex}; #{CANVAS_CSS}' />")
      $(options.elementSelector).append(layer)
      createdLayers[layerName] = layer
      zIndex++

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
        ctx.drawImage(assets[shape.asset], shape.position[0], shape.position[1])
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
    layers: ['default'] 

  layers = createLayers()

  return {
    provideData: -> 
      return {
        layers: options.layers
        size: options.size
        shapes: {}
      }

    establishData: (data, config, assets) -> 
      if not data.shapes then return 

      # Clear layers and create shapeArrays
      shapeArrays = {}
      for layerName, canvas of layers
        canvas[0].getContext('2d').clearRect(0, 0, options.size[0], options.size[1])
        shapeArrays[layerName] = []

      # Copy shapes from object into arrays based on their layer
      for id, shape of data.shapes
        layerName = shape.layer || 'default'
        if layerName not of layers then throw new Error('No layer for shape')

        shapeArrays[layerName].push(shape)

      # For each layer, sort shapes and then draw them
      for layerName, shapeArray of shapeArrays
        shapeArray.sort(shapeSorter)

        # TODO: handle composition for layers
        ctx = layers[layerName][0].getContext('2d')
        for shape in shapeArray then drawShape(shape, ctx, assets)

    destroy: -> 
      for layerName, canvas of layers then canvas.remove()
  }

# Define keyboard input service
GE.services.HTML = (options = {}) ->
  templates = { }
  layers = { }
  views = { }
  callbacks = { }

  rivets.configure
    handler: (target, event, binding) ->
      # binding.view.models.template will give the name of the template
      templates[binding.view.models.data]["values"][binding.keypath] = true

    adapter: 
      subscribe: (templateName, keypath, callback) -> 
        # console.log("subscribe called with ", arguments)
        callbacks[templateName][keypath] = callback
      unsubscribe: (templateName, keypath, callback) ->
        # console.log("unsubscribe called with ", arguments)
        delete callbacks[templateName][keypath]
      read: (templateName, keypath) ->
        # console.log("read called with ", arguments)
        return templates[templateName]["values"][keypath]
      publish: (templateName, keypath, value) ->
        # console.log("publish called with ", arguments)
        templates[templateName]["values"][keypath] = value

  return {
    provideData: () -> return { receive: templates, send: {} }

    establishData: (data, config, assets) -> 
      newTemplateData = data.send 

      # data.send and data.receive are in the template of { templateName: { asset: "", values: { name: value, ... }, ... }, ...}
      existingTemplates = _.keys(templates)
      newTemplates = _.keys(newTemplateData)

      # Remove all templates that are no longer to be shown
      for templateName in _.difference(existingTemplates, newTemplates) 
        delete templates[templateName]
        layers[templateName].remove()
        delete layers[templateName]
        views[templateName].unbind()
        delete views[templateName]
        delete callbacks[templateName]

      # Add new templates 
      for templateName in _.difference(newTemplates, existingTemplates) 
        # Create template
        templateHtml = assets[newTemplateData[templateName].asset]
        outerWrapper = $("<div id='html-#{templateName}' style='position: absolute; z-index: 100; pointer-events: none; width: #{options.size[0]}px; height: #{options.size[1]}px'/>")
        outerWrapper.append(templateHtml)
        $(options.elementSelector).append(outerWrapper)
        layers[templateName] = outerWrapper

        # Create newTemplateData
        templates[templateName] = newTemplateData[templateName] 
        # Bind to the template name
        callbacks[templateName] = { } # Will be filled by calls to adapter.subscribe()
        views[templateName] = rivets.bind(outerWrapper[0], { data: templateName })

      # Update existing templates with new newTemplateData
      for templateName in _.intersection(newTemplates, existingTemplates) 
        # TODO: call individual binders instead of syncronizing the whole model?
        #   for key in _.union(_.keys(newTemplateData[templateName].values), _.keys(templates[templateName].values)
        if not _.isEqual(newTemplateData[templateName].values, templates[templateName].values)
          templates[templateName].values = newTemplateData[templateName].values
          views[templateName].sync() 

      # Reset all event bindings to false
      for templateName, view of views
        for binding in view.bindings
          if binding.type.indexOf("on-") == 0
            templates[templateName]["values"][binding.keypath] = false

    # Remove all event handlers
    destroy: -> 
      for templateName, view of views
        view.unbind()
      for templateName, layer of layers
        layer.remove()
  }

# Define time service, that provides the current time in ms
GE.services.Time = () ->
  provideData: () -> return Date.now()
  establishData: () -> # NOP
  destroy: -> # NOP

# The HTTP service makes AJAX requests 
GE.services.Http = () ->
  state = 
    requests: {}
    responses: {}

  service =

    provideData: () -> return state

    establishData: (serviceData, config, assets) -> 
      # Expecting a format like { requests: { id: { method:, url:, data:, cache:, contentType: }, ... }, { responses: { id: { code:, data: }, ... }

      # Create new requests
      for requestName in _.difference(_.keys(serviceData.requests), _.keys(state.requests)) 
        do (requestName) ->
          jqXhr = $.ajax 
            url: serviceData.requests[requestName].url
            type: serviceData.requests[requestName].method ? "GET"
            cache: serviceData.requests[requestName].cache ? true
            data: serviceData.requests[requestName].data
            contentType: serviceData.requests[requestName].contentType
          jqXhr.done (data, textStatus) -> 
            state.responses[requestName] = 
              status: textStatus
              data: data
          jqXhr.fail (__, textStatus, errorThrown) -> 
            state.responses[requestName] = 
              status: textStatus
              error: errorThrown

          delete state.requests[requestName]

      # Remove deleted responses
      for requestName in _.difference(_.keys(state.responses), _.keys(serviceData.responses)) 
        delete state.responses[requestName]

      return state

    destroy: () -> # NOP

  return service

# Define chart output service
GE.services.Chart = (options = {}) ->
  capitalizeFirstLetter = (str) -> str[0].toUpperCase() + str.slice(1)

  # Format { name: { canvas:, data: }} 
  charts = {}

  removeChart = (chartName) ->
    charts[chartName].canvas.remove()
    delete charts[chartName]

  return {
    provideData: -> {}

    establishData: (serviceData, config, assets) -> 
      # Expecting serviceData like { chartA: { size:, position:, depth:, data:, options: }}

      # Remove old charts 
      for chartName in _.difference(_.keys(charts), _.keys(serviceData)) then removeChart(chartName)

      # Create new charts and update old ones
      for chartName, chartData of serviceData
        # If the chart already exists...
        if chartName of charts 
          #... and has the same data, don't bother redrawing it
          if _.isEqual(charts[chartName].data, chartData) then continue
          # Otherwise remove it.
          else removeChart(chartName)

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
        canvasProps = "id='chartLayer-#{chartName}' class='chartCanvas' width='#{displayOptions.size[0]}' height='#{displayOptions.size[1]}' tabIndex=0"
        canvasCss = "z-index: #{displayOptions.depth}; position: absolute; left: #{displayOptions.position[0]}px; top: #{displayOptions.position[1]}px;"
        canvas = $("<canvas #{canvasProps} style='#{canvasCss}' />")
        $(options.elementSelector).append(canvas)
        charts[chartName] = 
          canvas: canvas
          data: chartData

        # Create a new Chart object
        chart = new Chart(canvas[0].getContext("2d"))

        # Call the correct method on it
        chart[capitalizeFirstLetter(chartData.type)](chartData.data, chartOptions)

    destroy: -> 
      for chartName, canvas of charts then canvas.remove()
  }

