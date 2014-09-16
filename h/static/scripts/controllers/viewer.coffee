imports = [
  'h.searchfilters'
]

class ViewerController
  this.$inject = ['$scope', 'annotator']
  constructor:   ( $scope,   annotator ) ->
    # Tells the view that these annotations are embedded into the owner doc
    $scope.isEmbedded = true
    $scope.isStream = true

    $scope.activate = (annotation) ->
      if angular.isObject annotation
        highlights = [annotation.$$tag]
      else
        highlights = []
      for p in annotator.providers
        p.channel.notify
          method: 'setActiveHighlights'
          params: highlights

    $scope.shouldShowThread = (container) ->
      if $scope.selectedAnnotations? and not container.parent.parent
        $scope.selectedAnnotations[container.message?.id]
      else
        true

angular.module('h.controllers.Viewer', imports)
.controller('ViewerController', ViewerController)
