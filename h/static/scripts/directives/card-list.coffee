bounds = (card) ->
  {y1: card.top(), y2: card.top() + card.height()}

class Card
  constructor: (el, anchorTop=0) ->
    @_el = el
    @_top = anchorTop
    @_anchorTop = anchorTop
    @_cache = bounds(this)

  top: ->
    @_top

  setTop: (top) ->
    @_top = top

  height: ->
    @_el.outerHeight()

  anchorTop: ->
    @_anchorTop

  drawnBounds: ->
    @_cache

  draw: (offset=0) ->
    @_el.css('top', this.top() - offset)
    @_cache = bounds(this)

createCardList = ->
  OFFSET = 10
  CASCADE_FORWARDS = 'forwards'
  CASCADE_BACKWARDS = 'backwards'
  CASCADE_BOTH = 'both'
  MOVE_DEFAULTS = {direction: CASCADE_BOTH, force: false, prev: null, next: null}

  list = []

  isIntersecting = (a, b) ->
    return (a.y1 >= b.y1 && a.y1 <= b.y2) || (a.y2 >= b.y1 && a.y2 <= b.y2)

  indexOfCard = (card) ->
    list.indexOf(card)

  prevCard = (card) ->
    list[indexOfCard(card) - 1] || null

  nextCard = (card) ->
    list[indexOfCard(card) + 1] || null

  list.at = indexOfCard

  list.draw = (offset) ->
    card.draw(offset) for card in list

  list.anchor = (card) ->
    list.moveTo(card, card.anchorTop()) if card

  list.layout = ->
    for card in list
      prev = prevCard(card)
      pos = Math.max(card.anchorTop, prev && prev.height + prev.top + OFFSET)
      card.setTop(pos)

  list.moveTo = (card, position, options=MOVE_DEFAULTS) ->
    # return if card.top() == position

    prev = prevCard(card)
    next = nextCard(card)
    oldBounds = card.drawnBounds()
    cascadeForwards  = options.direction in [CASCADE_BOTH, CASCADE_FORWARDS]
    cascadeBackwards = options.direction in [CASCADE_BOTH, CASCADE_BACKWARDS]

    if options.force
      card.setTop(position)
    else
      limitMethod = if cascadeBackwards then 'min' else 'max'
      newPosition = Math[limitMethod](position, card.anchorTop())
      card.setTop(newPosition)

    newBounds = bounds(card)

    movementBounds =
      y1: Math.min(oldBounds.y1, newBounds.y1)
      y2: Math.max(oldBounds.y2, newBounds.y2)

    if newBounds.y1 > oldBounds.y1
      # Top of card has moved downwards pull previous card down.
      if cascadeBackwards && prev
        list.moveTo(prev, card.top() - prev.height() - OFFSET, {
          direction: CASCADE_BACKWARDS
        })

    if newBounds.y2 > oldBounds.y2
      # Bottom of card has moved down, push next card down.
      if cascadeForwards && next && isIntersecting(bounds(next), movementBounds)
        list.moveTo(next, card.top() + card.height() + OFFSET, {
          force: true
          direction: CASCADE_FORWARDS
        })

    if newBounds.y1 < oldBounds.y1
      # Top of card has moved up, push prev card up.
      if cascadeBackwards && prev && isIntersecting(bounds(prev), movementBounds)
        list.moveTo(prev, card.top() - prev.height() - OFFSET, {
          force: true
          direction: CASCADE_BACKWARDS
        })

    if newBounds.y2 < oldBounds.y2
      # Bottom of card has moved down, pull next card down.
      if cascadeForwards && next
        list.moveTo(next, card.top() + card.height() + OFFSET, {
          direction: CASCADE_FORWARDS
        })

  return list

class CardListController
  constructor: ->
    vm = this
    list = createCardList()
    count = 0

    vm.registerItem = (id, elem, index) ->
      card = new Card(elem, 0)
      list.splice(index, 0, card)

    vm.draw = (index) ->
      list.anchor(list[index])
      list.draw(window.scrollY)

cardList = [->
  linkFn = (scope, elem, attrs, ctrl) ->

  controller: 'CardListController'
  controllerAs: 'vm'
  link: linkFn
  require: []
  scope: true
]

cardListItem = ['$parse', ($parse) ->
  linkFn = (scope, elem, attrs, [cardList]) ->
    annotation = $parse(attrs.cardListItem)(scope)
    cardList.registerItem(annotation.id, elem, scope.$index)

    scope.$watch '$index', (val) ->
      console.log('has index %d', val)

    scope.$watch (-> elem.outerHeight()), ->
      cardList.draw(scope.$index)

  link: linkFn
  require: ['^cardList']
  scope: true
]

angular.module('h.directives')
.controller('CardListController', CardListController)
.directive('cardList', cardList)
.directive('cardListItem', cardListItem)
