# Define keyboard input service
registerService "Keyboard", (options) ->
  options = _.defaults options,
    elementSelector: "#gameCanvas"

  eventNamespace = _.uniqueId("keyboard")

  keysDown = {}

  $(options.elementSelector).on "keydown.#{eventNamespace} keyup.#{eventNamespace} blur.#{eventNamespace}", (event) ->
    # jQuery standardizes the keycode into http://api.jquery.com/event.which/
    switch event.type 
      when "keydown" then keysDown[event.which] = true
      when "keyup" then delete keysDown[event.which]
      when "blur" then keysDown = {} # Lost focus, so will not receive keyup events
      else throw new Error("Unexpected event type")      

  return {
    provideData: -> return { "keysDown": keysDown }

    establishData: -> # NOOP. Input service does not take data

    # Remove all event handlers
    destroy: -> $(options.elementSelector).off(".#{eventNamespace}")
  }

# Define mouse input service
registerService "Mouse", (options) ->
  options = _.defaults options,
    elementSelector: "#gameCanvas"

  eventNamespace = _.uniqueId("mouse")

  mouse =
    down: false
    position: null

  $(options.elementSelector).on "mousedown.#{eventNamespace} mouseup.#{eventNamespace} mousemove.#{eventNamespace} mouseleave.#{eventNamespace}", (event) ->
    switch event.type 
      when "mousedown" then mouse.down = true
      when "mouseup" then mouse.down = false
      when "mouseleave" 
        mouse.down = false
        mouse.position = null
      when "mousemove"
        # Get position relative to canvas.
        # Based on http://www.html5canvastutorials.com/advanced/html5-canvas-mouse-coordinates/
        rect = $(options.elementSelector)[0].getBoundingClientRect()
        mouse.position = 
          x: event.clientX - rect.left
          y: event.clientY - rect.top
      else throw new Error("Unexpected event type")

  return {
    provideData: -> return mouse

    establishData: -> # NOOP. Input service does not take data

    # Remove all event handlers
    destroy: -> $(options.elementSelector).off(".#{eventNamespace}")
  }

# Define canvas output service
registerService "Canvas", (options) ->
  options = _.defaults options,
    elementSelector: "#gameCanvas"
    layers: 
      default: 
        order: 0

  # Default 
  layerOrderForShape = (shape) ->
    if not shape.layer? then return 0
    if shape.layer not of options.layers then return 0
    return options.layers[shape.layer].order or 0 

  shapeSorter = (a, b) -> return layerOrderForShape(a) - layerOrderForShape(b)

  interpretStyle = (style, ctx) ->
    if _.isString(style) then return style
    if not _.isObject(style) then throw new Error("Style must be string or object")

    switch style.type
      when "radialGradient"
        grad = ctx.createRadialGradient(style.start.position[0], style.start.position[1], style.start.radius, style.end.position[0], style.end.position[1], style.end.radius)
        for colorStop in style.colorStops
          grad.addColorStop(colorStop.position, colorStop.color)
        return grad
      when "linearGradient"
        grad = ctx.createLinearGradient(style.startPosition[0], style.startPosition[1], style.endPosition[0], style.endPosition[1])
        for colorStop in style.colorStops
          grad.addColorStop(colorStop.position, colorStop.color)
        return grad
      else throw new Error("Unknown or missing style type")

  handleTransformations = (shape, ctx) ->
    # Not sure this is done in the right order
    if shape.translation then ctx.translate(shape.translation[0], shape.translation[1])
    if shape.rotation then ctx.rotate(shape.rotation * Math.PI / 180) # Convert to radians
    if shape.scale 
      if _.isArray(shape.scale) then ctx.scale(shape.scale[0], shape.scale[1])
      else if _.isNumber(shape.scale) then ctx.scale(shape.scale, shape.scale)
      else throw new Error("Scale argument must be number or array")

  executeShape = (shape, ctx, assets) ->
    # TODO: verify that arguments are of the correct type (the canvas API will not complain, just misfunction!)
    ctx.save()
    handleTransformations(shape, ctx)

    switch shape.type
      when "rectangle" 
        if shape.fillStyle
          ctx.fillStyle = interpretStyle(shape.fillStyle, ctx)
          ctx.fillRect(shape.position[0], shape.position[1], shape.size[0], shape.size[1])
        if shape.strokeStyle
          ctx.strokeStyle = interpretStyle(shape.strokeStyle, ctx)
          ctx.strokeRect(shape.position[0], shape.position[1], shape.size[0], shape.size[1])
      when "image"
        ctx.drawImage(assets[shape.asset], shape.position[0], shape.position[1])
      when "text"
        text = _.isString(shape.text) && shape.text || JSON.stringify(shape.text)
        ctx.strokeStyle = interpretStyle(shape.style, ctx)
        ctx.font = shape.font
        ctx.strokeText(text, shape.position[0], shape.position[1])
      when "path"
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
      when "circle"
        ctx.moveTo(shape.position[0], shape.position[1])
        ctx.arc(shape.position[0], shape.position[1], shape.radius, 0, 2 * Math.PI)
        if shape.fillStyle
          ctx.fillStyle = interpretStyle(shape.fillStyle, ctx)
          ctx.fill()
        if shape.strokeStyle
          ctx.strokeStyle = interpretStyle(shape.strokeStyle, ctx)
          ctx.stroke()
      else throw new Error("Unknown or missing shape type")
    ctx.restore()

  return {
    provideData: -> 
      canvas = $(options.elementSelector)
      return {
        width: canvas.prop("width")
        height: canvas.prop("height")
        shapes: []
      }

    establishData: (data, assets) -> 
      if not data.shapes then return 

      ctx = $(options.elementSelector)[0].getContext("2d")
      data.shapes.sort(shapeSorter)
      for shape in data.shapes
        # TODO: handle composition for layers
        executeShape(shape, ctx, assets)

    destroy: -> # NOOP
  }

