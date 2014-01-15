angular.module('gamEvolve.game.edit', ['flexyLayout', 'JSONedit'])

    .config(function ($stateProvider) {
        $stateProvider.state('game.edit', {
            url: '/:gameId/edit',
            views: {
                "game.main": {
                    controller: 'GameEditCtrl',
                    templateUrl: 'game/edit/gameEdit.tpl.html'
                }
            },
            data: { pageTitle: 'Edit Game' }
        });
    })

    .controller('GameEditCtrl', function HomeController($scope, $filter, currentGame, boardConverter) {

        $scope.currentGame = currentGame;

        $scope.model = {};
        if (currentGame.version) {
            $scope.model = JSON.parse(currentGame.version.model);
        }
        $scope.$watch('model', function (jso) {
            if (currentGame.version)
                currentGame.version.model = $filter('json')(jso);
        }, true);
        $scope.$watch('currentGame.version.model', function (json) {
            if (json)
                $scope.model = JSON.parse(json);
        }, false);

        $scope.board = {};
        $scope.$watch('currentGame.version.layout', function (json) {
            if (json) {
                var converted = boardConverter.convert(JSON.parse(json));
                $scope.board = converted;
            }
        }, false);

    })

;

