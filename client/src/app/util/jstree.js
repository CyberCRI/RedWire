var dnd = {
    'drag_check' : function (data) {
        if(data.r.attr('rel') === 'action') { // No dropping in actions
            return false;
        }
        // For simplicity's sake, DnD is allowed only for adding actions INSIDE tree nodes
        return {
            after : false,
            before : false,
            inside : true
        };
    },
    'drag_finish' : function (data) {
        // TODO Generate proper data
        this.create(data.r, 'inside', data.o.attributes['action-id'].nodeValue, null, true);
    }
};

var types = {
    'types' : {
        'switch' : {
            'icon' : {
                'image' : '/assets/images/switch.png'
            }
        },
        'action' : {
            'valid_children' : [] // Actions are leafs in the tree
        }
    }
};

angular.module('gamEvolve.util.jstree', [])

    .directive('jstree', function() {
        return {

            restrict: 'A',
            scope: { jstree: '=' },
            link: function (scope, element, attrs) {
                scope.$watch('jstree', function () {
                    $(element).jstree({
                        'json_data' : {
                            'data' : scope.jstree
                        },
                        'dnd' : dnd,
                        'types' : types,
                        'core': { html_titles: true },
                        'plugins' : [ 'themes', 'ui', 'json_data', 'dnd', 'types', 'wholerow', 'crrm' ]
                    });
                });
                var emitEditEvent = function(path) {
                    scope.$emit('editChipButtonClick', JSON.parse(path));
                }
                $(element).on('click', 'a[editChip]', function(eventObject) {
                    var clicked = $(eventObject.target);
                    if ( clicked.attr('editChip') ) {
                        emitEditEvent( clicked.attr('editChip') );
                    } else {
                        emitEditEvent( $(clicked.parent()[0]).attr('editChip') );
                    }
                });
                var emitRemoveEvent = function(path) {
                    scope.$emit('removeChipButtonClick', JSON.parse(path));
                }
                $(element).on('click', 'a[removeChip]', function(eventObject) {
                    var clicked = $(eventObject.target);
                    if ( clicked.attr('removeChip') ) {
                        emitRemoveEvent( clicked.attr('removeChip') );
                    } else {
                        emitRemoveEvent( $(clicked.parent()[0]).attr('removeChip') );
                    }
                });
            }
        };
    });