angular.module('gamEvolve.game.assets', [
  'ui.bootstrap'
  'omr.angularFileDnD'
  'xeditable'
])

.controller 'AssetsCtrl', ($scope, currentGame) ->
  # Get the actions object from the currentGame service, and keep it updated
  $scope.assets = null
  $scope.fileName = ""
  $scope.file = null

  # Transform assets to array so we can loop over it easier
  copyFromGameToScope = -> 
    if currentGame.version?
      $scope.assets = ({ name: name, data: data } for name, data of currentGame.version.assets)

  # Bring currentGame into scope so we can watch it 
  $scope.currentGame = currentGame
  $scope.$watch("currentGame.localVersion", copyFromGameToScope, true)

  # Transform assets back to object so we can loop over it easier
  copyFromScopeToGame = -> 
    if $scope.assets == null then return 

    assetsAsObject = _.object(([asset.name, asset.data] for asset in $scope.assets))
    if _.isEqual(assetsAsObject, currentGame.version.assets) then return 

    currentGame.version.assets = assetsAsObject
    currentGame.updateLocalVersion()
  $scope.$watch("assets", copyFromScopeToGame, true)

  $scope.remove = (index) -> 
    if window.confirm("Are you sure you want to delete this asset?")
      $scope.assets.splice(index, 1)

  $scope.$watch "file", ->
    if $scope.fileName is "" then return 

    $scope.assets.push({ name: $scope.fileName, data: $scope.file })
    # Reset this so that the same filename dragged twice in a row will be taken into account
    $scope.fileName = ""  
    $scope.file = null

.directive 'assetDrag', ($parse, dndHelper) ->
    restrict: 'A'
    link: (scope, element, attrs) ->
      el = element[0]
      parsedDrag = $parse(attrs.assetDrag)
      el.draggable = true

      el.addEventListener "dragstart", (e) ->
        e?.stopPropagation()
        e.dataTransfer.effectAllowed = 'copy'
        data = parsedDrag(scope)
        dndHelper.setDraggedData({ asset: data })
        return false

      el.addEventListener "dragend", (e) ->
        e?.stopPropagation()
        return false;

.directive "assetDropzone", (currentGame, dndHelper, circuits) ->
  restrict: 'A',
  link: (scope, element, attrs) ->
    acceptDrop = (event) -> dndHelper.getDraggedData()?.asset?

    el = element[0]
    el.addEventListener "drop", (event) -> 
      if not acceptDrop(event) then return false

      event.preventDefault?() 
      event.stopPropogation?() 
      console.log("drop asset")

      draggedData = dndHelper.getDraggedData(event)
      
      currentGame.version.assets[draggedData.asset.name] = draggedData.asset.data
      currentGame.updateLocalVersion()

      return false
