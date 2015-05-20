PrivacyController = [ '$scope', '$rootScope', ($scope, $rootScope) ->

  $scope.VISIBILITY_KEY ='hypothesis.visibility'
  $scope.VISIBILITY_PUBLIC = 'public'
  $scope.VISIBILITY_PRIVATE = 'private'
  $scope.VISIBILITY_GROUP = $rootScope.socialview.name
  $scope.viewnamelist = ['All']

  $scope.levels = [
    {name: $scope.VISIBILITY_PUBLIC, text: 'Public', icon:'h-icon-public'}
    {name: $scope.VISIBILITY_PRIVATE, text: 'Only Me', icon:'h-icon-lock'}
  ]

  $scope.getLevel = (name) ->
    for level in $scope.levels
      if level.name == name
        return level
    undefined

  $scope.isPublic  = (level) -> level == $scope.VISIBILITY_PUBLIC

  $scope.isGroup  = (level) -> 
    level != ( $scope.VISIBILITY_PRIVATE or $scope.VISIBILITY_PUBLIC )

]

module.exports = ['localStorage', 'permissions', '$rootScope', (localStorage, permissions, $rootScope) ->

  link: (scope, elem, attrs, controller) ->
    return unless controller?

    controller.$formatters.push (selectedPermissions) ->
      return unless selectedPermissions?

      if permissions.isPublic(selectedPermissions)
        scope.getLevel(scope.VISIBILITY_PUBLIC)
      # else if permissions.isGroup(selectedPermissions)
      #   scope.getLevel(scope.VISIBILITY_GROUP)
      else
        scope.getLevel(scope.VISIBILITY_PRIVATE)

    controller.$parsers.push (privacy) ->
      return unless privacy?

      if scope.isPublic(privacy.name)
        newPermissions = permissions.public()
      else if scope.isGroup(privacy.name)
        newPermissions = permissions.public()
      else
        newPermissions = permissions.private()

      # Cannot change the $modelValue into a new object
      # Just update its properties
      for key,val of newPermissions
        controller.$modelValue[key] = val

      controller.$modelValue

    controller.$render = ->
      unless controller.$modelValue.read?.length
        if $rootScope.socialview.name == 'All'
          name = localStorage.getItem scope.VISIBILITY_KEY
          name ?= scope.VISIBILITY_PUBLIC
        else
          name = scope.VISIBILITY_GROUP
        level = scope.getLevel(name)
        controller.$setViewValue level

      $rootScope.level = controller.$viewValue
      console.log $rootScope.level
      scope.level = controller.$viewValue

    scope.setLevel = (level) ->
      localStorage.setItem scope.VISIBILITY_KEY, level.name
      controller.$setViewValue level
      controller.$render()


    for view in $rootScope.views
      if view.name not in scope.viewnamelist
        scope.viewnamelist.push view.name
        scope.levels.push {name: scope.VISIBILITY_GROUP, text: view.name, icon:'h-icon-group'}

  require: '?ngModel'
  controller: PrivacyController
  restrict: 'E'
  scope: {}
  templateUrl: 'privacy.html'
]
