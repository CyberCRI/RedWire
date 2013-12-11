angular.module('gamEvolve.game.edit', ['flexyLayout'])

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

    .controller('GameEditCtrl', function HomeController($scope) {
    })

;

