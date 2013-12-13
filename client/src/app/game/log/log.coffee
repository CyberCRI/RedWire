angular.module('gamEvolve.game.log', [])
.controller('LogCtrl', ($scope) ->
    $scope.text = "Hello!"
    $scope.aceLoaded = (editor) -> 
      editor.setReadOnly(true)
)
