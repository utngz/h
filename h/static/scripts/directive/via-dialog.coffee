###*
# @ngdoc directive
# @name viaLinkDialog
# @restrict A
# @description The dialog that generates a via link to the page h is currently
# loaded on.
###
module.exports = ['$timeout', 'crossframe', 'via', '$rootScope', (
                   $timeout,   crossframe,   via,   $rootScope) ->
    link: (scope, elem, attrs, ctrl) ->
        scope.viaPageLink = ''

        ## Watch viaLinkVisible: when it changes to true, focus input and selection.
        scope.$watch (-> scope.viaLinkDialog.visible), (visible) ->
            if visible
                $timeout (-> elem.find('#via').focus().select()), 0, false

        scope.$watch (-> $rootScope.socialview.name), (socialview) ->
            if socialview != 'All'
                # Change the text shown on the dialog to reflect that we are now
                # sharing a group.
                return true

        scope.$watchCollection (-> crossframe.providers), ->
            if crossframe.providers?.length
                # XXX: Consider multiple providers in the future
                p = crossframe.providers[0]
                if p.entities?.length
                    e = p.entities[0]
                    scope.viaPageLink = via.url + e
    controller: 'AppController'
    templateUrl: 'via_dialog.html'
]
