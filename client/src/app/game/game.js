angular.module('gamEvolve.game', ['flexyLayout'])

    .config(function config($stateProvider) {
        $stateProvider
            .state('game', {
                url: '/game',
                views: {
                    "main": {
                        templateUrl: 'game/game.tpl.html'
                    }
                },
                abstract: true
            })
        ;
    })

;