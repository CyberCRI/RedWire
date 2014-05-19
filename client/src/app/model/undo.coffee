angular.module('gamEvolve.model.undo', [])
.factory 'undo', ->
  # TODO: backup data by localstorage
  # TODO: store diffs to save space?

  # TODO: remove the meta and data portions?
  meta:
    # Need to update the version at each change of the data
    version: 0
  data:
    stack: []
    index: 0

  reset: ->
    @data.stack = []
    @data.index = -1 # The index points to the current version on the stack, so it will go to 0 on the first push

    @meta.version = 0

  # Returns [id, data]
  getCurrent: -> 
    RW.cloneData(if @data.index < @data.stack.length then @data.stack[@data.index] else null)

  canUndo: -> @data.index > 0
  undo: -> 
    @data.index--
    return @getCurrent()

  canRedo: -> @data.index < @data.stack.length - 1
  redo: -> 
    @data.index++
    return @getCurrent()

  changeValue: (id, data) ->
    if @canRedo()
      # Remove any redos
      # Start at the element following the index, and remove to the end of the array
      @data.stack.splice(@data.index + 1, @data.stack.length - @data.index - 1)

    # Push the new value onto the stack
    @data.stack.push([id, RW.cloneData(data)])
    @data.index++
