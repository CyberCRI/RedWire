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
    if @data.index < @data.stack.length then @data.stack[@data.index] else null

  canUndo: -> @data.index > 0
  undo: -> 
    @data.index--
    return @getCurrent()

  canRedo: -> @data.index < @data.stack.length - 1
  redo: -> 
    @data.index++
    return @getCurrent()

  changeValue: (id, data) ->
    # Remove any redos
    if @canRedo()
      @data.stack.splice(@data.index, @data.stack.length - @data.index)

    # Push the new value onto the stack
    @data.stack.push([id, RW.cloneData(data)])
    @data.index++
