# Define keyboard input service
registerService 'Keyboard', (options = {}) ->
  options = _.defaults options,
    elementSelector: '#gameContent'

  eventNamespace = _.uniqueId('keyboard')

  keysDown = {}

  $(options.elementSelector).on "keydown.#{eventNamespace} keyup.#{eventNamespace} focusout.#{eventNamespace}", (event) ->
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
registerService 'Mouse', (options = {}) ->
  options = _.defaults options,
    elementSelector: '#gameContent'

  eventNamespace = _.uniqueId('mouse')

  mouse =
    down: false
    position: null
    cursor: null

  # This disables selection, which allows the cursor to change in Chrome
  $(options.elementSelector).on("selectstart.#{eventNamespace}", -> false)

  $(options.elementSelector).on "mousedown.#{eventNamespace} mouseup.#{eventNamespace} mousemove.#{eventNamespace} mouseleave.#{eventNamespace}", (event) ->
    switch event.type 
      when 'mousedown' then mouse.down = true
      when 'mouseup' then mouse.down = false
      when 'mouseleave' 
        mouse.down = false
        mouse.position = null
      when 'mousemove'
        # Get position relative to canvas.
        # Based on http://www.html5canvastutorials.com/advanced/html5-canvas-mouse-coordinates/
        rect = event.target.getBoundingClientRect()
        target = $(event.target)
        mouse.position = 
          x: Math.floor((event.clientX - rect.left) * target.attr("width") / rect.width)
          y: Math.floor((event.clientY - rect.top) * target.attr("height") / rect.height)
      else throw new Error('Unexpected event type')

  return {
    provideData: -> return mouse

    establishData: (data) -> 
      $(options.elementSelector).css("cursor", data.cursor || "")

    # Remove all event handlers
    destroy: -> $(options.elementSelector).off(".#{eventNamespace}")
  }

# Define canvas output service
registerService 'Canvas', (options = {}) ->
  # `height: 100%` preserves the aspect ratio. Make the position absolute keeps the layers on top of each other
  CANVAS_CSS = "height: 100%; position: absolute; left: 0px; top: 0px;"

  createLayers = ->
    # Convert layers to ordered
    createdLayers = {}
    zIndex = 0
    for layerName in options.layers
      layer = $("<canvas id='canvasLayer-#{layerName}' class='gameCanvas' width='#{options.size[0]}' height='#{options.size[1]}' tabIndex='0' style='z-index: #{zIndex}; #{CANVAS_CSS}' />")
      $('#gameContent').append(layer)
      createdLayers[layerName] = layer

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
        ctx.strokeStyle = interpretStyle(shape.style, ctx)
        ctx.font = shape.font
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
        ctx.moveTo(shape.position[0], shape.position[1])
        ctx.arc(shape.position[0], shape.position[1], shape.radius, 0, 2 * Math.PI)
        if shape.fillStyle
          ctx.fillStyle = interpretStyle(shape.fillStyle, ctx)
          ctx.fill()
        if shape.strokeStyle
          ctx.strokeStyle = interpretStyle(shape.strokeStyle, ctx)
          ctx.stroke()
      else throw new Error('Unknown or missing shape type')
    ctx.restore()

  options = _.defaults options,
    layers: ['default'] 
    size: [960, 540]
  layers = createLayers()

  return {
    provideData: -> 
      return {
        layers: options.layers
        size: options.size
        shapes: []
      }

    establishData: (data, assets) -> 
      if not data.shapes then return 

      # Clear layers
      for layerName, canvas of layers
        canvas[0].getContext('2d').clearRect(0, 0, options.size[0], options.size[1])

      # Sort shapes and send them to their layers
      data.shapes.sort(shapeSorter)

      # OPT: group all manipulations by layer before drawing them?
      for shape in data.shapes
        layerName = shape.layer || 'default'
        if layerName not of layers then throw new Error('No layer for shape')

        ctx = layers[layerName][0].getContext('2d')
        # TODO: handle composition for layers
        drawShape(shape, ctx, assets)

    destroy: -> 
      for layerName, canvas of layers then canvas.remove()
  }

