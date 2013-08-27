# Define keyboard input service
registerService 'Keyboard', (options = {}) ->
  options = _.defaults options,
    elementSelector: '#gameContent'

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

  $(options.elementSelector).on "mousedown.#{eventNamespace} mouseup.#{eventNamespace} mousemove.#{eventNamespace} mouseleave.#{eventNamespace}", "canvas", (event) ->
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
        mouse.position = [
          Math.floor((event.clientX - rect.left) * target.attr("width") / rect.width)
          Math.floor((event.clientY - rect.top) * target.attr("height") / rect.height)
        ]
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

  options = _.defaults options,
    elementSelector: '#gameContent'

  createLayers = ->
    # Convert layers to ordered
    createdLayers = {}
    zIndex = 0
    for layerName in options.layers
      layer = $("<canvas id='canvasLayer-#{layerName}' class='gameCanvas' width='#{options.size[0]}' height='#{options.size[1]}' tabIndex='0' style='z-index: #{zIndex}; #{CANVAS_CSS}' />")
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
    size: [960, 540]
  layers = createLayers()

  return {
    provideData: -> 
      return {
        layers: options.layers
        size: options.size
        shapes: {}
      }

    establishData: (data, assets) -> 
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
registerService 'HTML', (options = {}) ->
  options = _.defaults options,
    elementSelector: '#gameContent'

  forms = { }
  layers = { }
  views = { }
  callbacks = { }

  rivets.configure
    handler: (target, event, binding) ->
      console.log("event handler called with", arguments, ". this is", this)
      forms[binding.key]["values"][binding.keypath] = true

    adapter: 
      subscribe: (formName, keypath, callback) -> 
        console.log("subscribe called with ", arguments)
        callbacks[formName][keypath] = callback
      unsubscribe: (formName, keypath, callback) ->
        console.log("unsubscribe called with ", arguments)
        delete callbacks[formName][keypath]
      read: (formName, keypath) ->
        console.log("read called with ", arguments)
        return forms[formName]["values"][keypath]
      publish: (formName, keypath, value) ->
        console.log("publish called with ", arguments)
        forms[formName]["values"][keypath] = value

  return {
    provideData: () -> return forms

    establishData: (data, assets) -> 
      # Data is in the format of { formName: { asset: "", values: { name: value, ... }, ... }, ...}
      existingForms = _.keys(forms)
      newForms = _.keys(data)

      # Remove all forms that are no longer to be shown
      for formName in _.difference(existingForms, newForms) 
        delete forms[formName]
        layers[formName].remove()
        delete layers[formName]
        views[formName].unbind()
        delete views[formName]
        delete callbacks[formName]

      # Add new forms 
      for formName in _.difference(newForms, existingForms) 
        # Create form
        formHtml = assets[data[formName].asset]
        layer = $("<div id='html-#{formName}' style='position: absolute; z-index: 100'/>").append(formHtml)
        $(options.elementSelector).append(layer)
        layers[formName] = layer

        # Create data
        forms[formName] = data[formName] 
        # Bind to the form name
        callbacks[formName] = { } # Will be filled by calls to adapter.subscribe()
        views[formName] = rivets.bind(layer[0], { form: formName })

      # Update existing forms with new data
      for formName in _.intersection(newForms, existingForms) 
        # TODO: call individual binders instead of syncronizing the whole model?
        #   for key in _.union(_.keys(data[formName].values), _.keys(forms[formName].values)
        if not _.isEqual(data[formName].values, forms[formName].values)
          forms[formName].values = data[formName].values
          views[formName].sync() 

      # Reset all event bindings to false
      for formName, view of views
        for binding in view.bindings
          if binding.type.indexOf("on-") == 0
            forms[binding.key]["values"][binding.keypath] = false

    # Remove all event handlers
    destroy: -> 
      for formName, view of views
        view.unbind()
      for formName, layer of layers
        layer.remove()


  }


