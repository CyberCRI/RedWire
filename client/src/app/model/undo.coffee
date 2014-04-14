angular.module('gamEvolve.model.undo', [])
.factory 'undo', ->
  # TODO: backup data by localstorage

  # TODO: remove the meta and data portions?
  meta:
    # Need to update the version at each change of the data
    version: 0
  data:
    stack: []
    index: 0

  reset: ->
    @data.stack = []
    @data.index = 0

    @meta.version = 0

  currentValue: -> if @data.index < @data.stack.length then @data.stack[@data.index] else null

  canUndo: -> @data.index > 0
  undo: -> 
    @data.index--
    return currentData()

  canRedo: -> @data.index < @data.stack.length - 1
  redo: -> 
    @data.index++
    return currentData()

  changeValue: (value) ->
    # Remove any redos
    if @canRedo()
      @data.stack.splice(@data.index, @data.stack.length - @data.index)

    # Push the new value onto the stack
    @data.stack.push(value)
    @data.index++
