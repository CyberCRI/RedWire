NOTIFICATION_TIME = 3000 # in ms


angular.module('gamEvolve.game.overlay', [])
.controller "OverlayCtrl", ($scope, $timeout, overlay) -> 
  $scope.showOverlay = false
  $scope.notification = 
    icon: "font-icon-record"
    text: "Recording..."

  createNotification = ->
    if not overlay.notification? then return null

    # If the notification expires, return null
    if not overlay.notification.keep and Date.now() - overlay.notification.time > NOTIFICATION_TIME then return null

    switch overlay.notification.type
      when "recording" 
        icon: "font-icon-record"
        text: "Recording"
      when "updating"
        icon: "font-icon-spin3"
        text: "Updating"
      when "waiting"
        icon: "font-icon-spin5"
        text: "Waiting..."
      when "stopped"
        icon: "font-icon-pause"
        text: "Stopped"
      when "error"
        icon: "font-icon-error-alt"
        text: "Uh oh!"

  onUpdate = ->
    $scope.notification = createNotification()
    # Show the overlay if there is a current notification or if we are dragging the borders
    $scope.showOverlay = $scope.notification? || overlay.draggingBorders

    # Get ready to cancel the notification when it expires
    if $scope.notification then $timeout(onUpdate, 100)

  # Bring the service into scope to watch it
  $scope.overlay = overlay
  $scope.$watch("overlay", onUpdate, true)

