var dnd = {
    "drag_check" : function (data) {
        if(data.r.attr("rel") === "action") { // No dropping in actions
            return false;
        }
        // For simplicity's sake, DnD is allowed only for adding actions INSIDE tree nodes
        return {
            after : false,
            before : false,
            inside : true
        };
    },
    "drag_finish" : function (data) {
        // TODO Generate proper data
        this.create(data.r, "inside", data.o.attributes['action-id'].nodeValue, null, true);
    }
};

var types = {
    "types" : {
        "switch" : {
            "icon" : {
                "image" : "/assets/images/switch.png"
            }
        },
        "action" : {
            "valid_children" : [] // Actions are leafs in the tree
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
                        "json_data" : {
                            "data" : scope.jstree
                        },
                        "dnd" : dnd,
                        "types" : types,
                        "plugins" : [ "themes", "ui", "json_data", "dnd", "types", "wholerow", "crrm" ]
                    });
                });
            }
        };
    });