angular.module('gamEvolve.model.undo', [])
.factory 'undo', ->
  # TODO: store diffs to save space?

  stack: []
  index: 0

  reset: ->
    @stack = []
    @index = -1 # The index points to the current version on the stack, so it will go to 0 on the first push

  # Returns [id, data]
  getCurrent: -> 
    RW.cloneData(if @index < @stack.length then @stack[@index] else null)

  canUndo: -> @index > 0
  undo: -> 
    @index--
    return @getCurrent()

  canRedo: -> @index < @stack.length - 1
  redo: -> 
    @index++
    return @getCurrent()

  changeValue: (id, data) ->
    if @canRedo()
      # Remove any redos
      # Start at the element following the index, and remove to the end of the array
      @stack.splice(@index + 1, @stack.length - @index - 1)

    # Push the new value onto the stack
    @stack.push([id, RW.cloneData(data)])
    @index++

  isEmpty: -> @stack.length == 0
