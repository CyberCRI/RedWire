angular.module('gamEvolve.model.overlay', [])
.factory 'overlay', ->
  draggingBorders: false
  notification: 
    type: "" 
    time: 0 # time in ms, from Date.now() 

  makeNotification: (type, keep = false) ->
    this.notification = 
      type: type
      keep: keep
      time: Date.now()

  clearNotification: -> this.notification = null
