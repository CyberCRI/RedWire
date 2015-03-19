module = angular.module('gamEvolve.util.pins', [])

module.factory 'pins', (circuits, currentGame) ->
  enumeratePinDestinations: ->
    destinations = @enumerateMemoryKeys(currentGame.version.circuits[circuits.currentCircuitMeta.type].memory)
    @enumerateIoKeys(RW.io, destinations)
    return destinations

  enumerateMemoryKeys: (memory, prefix = ['memory'], keys = []) ->
    for name, value of memory
      keys.push(RW.appendToArray(prefix, name).join('.'))
      if RW.isOnlyObject(value) then @enumerateMemoryKeys(value, RW.appendToArray(prefix, name), keys)
    return keys

  # TODO: These should be filled by the IO services themselves, but it requires sending them the list of circuits and layers, since we don't share the same instance
  enumerateIoKeys: (ioServices,  keys = []) ->
    # List basic IO services
    for service in ["time", "http"] then keys.push("io.#{service}")

    # Fill in keyboard pins
    keys.push("io.keyboard.keysDown")

    # Fill in mouse pins
    for pin in ["down", "position", "cursor", "justDown", "justUp"] then keys.push("io.mouse.#{pin}")

    # Fill in metrics pins
    for pin in ["player", "events"] then keys.push("io.metrics.#{pin}")

    # Fill in layer pins
    layers = currentGame.version.circuits[circuits.currentCircuitMeta.type].io.layers
    for layer in layers 
      keys.push("io.#{layer.type}.#{layer.name}")

    # Fill in sound pins
    # TODO: change name to io.#{channel.type}.#{channel.name} ?
    channels = currentGame.version.circuits[circuits.currentCircuitMeta.type].io.channels
    for channel in channels
      keys.push("io.sound.#{channel.name}")

    # Fill in circuit pins
    pins = currentGame.version.circuits[circuits.currentCircuitMeta.type].pinDefs || {}
    for pinName, pinDef of pins
      keys.push("circuit.#{pinName}")

    # Fill in metrics pins
    for pin in ["down", "position", "cursor", "justDown", "justUp"] then keys.push("io.mouse.#{pin}")

    # Fill in location pins
    for pin in ["url", "protocol", "host", "port", "path", "query", "hash"] then keys.push("io.location.#{pin}")

    return keys
