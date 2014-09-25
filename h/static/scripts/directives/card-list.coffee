# The CardList module deals with rendering a list of cards for the Annotation
# viewer and keeping them in position relative to the highlights in the parent
# document. The code itself is ignorant of this and only deals with positioning
# elements relative to each other.

# Creates a bounds object from a card. A bounds object represents a vertical
# line in space.
bounds = (card) ->
  {y1: card.top(), y2: card.top() + card.height()}

# Returns true if the two bounds provided are intersecting.
isIntersecting = (a, b) ->
  return (a.y1 >= b.y1 && a.y1 <= b.y2) || (a.y2 >= b.y1 && a.y2 <= b.y2)

# A card represents a single item in a list. This is an HTMLElement with an
# anchor position. This anchor represents it's canonical vertical position.
# The position of the card can change as the elements in the list interact
# with each other. When a card is drawn it updates the top offset of the
# dom element and caches it's position. This can then be queried later to
# see where the element has been moved to.
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

  # A bounds object for the Card the last time it was updated.
  drawnBounds: ->
    @_cache

  # Updates the position of the element in the document. An offset can be
  # provided to tweak where the element is positioned while
  # retaining it's internal relative position. This is useful for offsetting
  # the element in a fixed container based on the scroll position for example.
  draw: (offset=0) ->
    # TODO: Use transform: translateX() here for a performance boost.
    @_el.css('top', this.top() - offset)
    @_cache = bounds(this)

# A CardList is an augmented array of Card items and handles their positioning
# in the view. It is this object through the .moveTo method that handles
# how cards interact with each other when they move.
createCardList = ->
  OFFSET = 10
  CASCADE_FORWARDS = 'forwards'
  CASCADE_BACKWARDS = 'backwards'
  CASCADE_BOTH = 'both'
  MOVE_DEFAULTS = {direction: CASCADE_BOTH, force: false, prev: null, next: null}

  list = []

  # Returns the index of the provided card in the array. This should be
  # used over list.indexOf as it may be more performant.
  indexOfCard = (card) ->
    list.indexOf(card) # TODO: Maintain a hash map to speed up lookup.

  # Find the previous card in the list.
  prevCard = (card) ->
    list[indexOfCard(card) - 1] || null

  # Find the next card in the list.
  nextCard = (card) ->
    list[indexOfCard(card) + 1] || null

  # Update the position of all the cards. The offset is the window.scrollY
  # of the target document.
  list.draw = (offset) ->
    card.draw(offset) for card in list

  # Takes a card and moves it to it's anchor point.
  list.anchor = (card) ->
    list.moveTo(card, card.anchorTop()) if card

  # Moves a card into position and updates it's surrounding cards.
  #
  # The card positioning is a recursive cascade where a call to .moveTo will
  # position the card provided as well as the preceding and following card in
  # the list. This way we can position each card relative to the current one
  # like links in a chain.
  #
  # The logic for moving a card is relatively straight forward.
  #
  # 1) A next/prev card will only be updated if a) movement of the current card
  #    passes within its bounds (ie. it is pushed along).
  # 2) Or if the current card moves away from the prev/next card in which case
  #    the prev/next card is pulled along. A pulled card will only move as far
  #    as it's anchor point. It will always stop at this point.
  #
  # There are two properties of the options object that represent how the card
  # should be moved.
  #
  # force: If this is true then the card is being pushed by it's neighbour and
  #   we should not respect the anchor point. Otherwise the card will never
  #   move beyond it's anchor point.
  # direction: This indicates the direction the card is moving. By default
  #   this is set to CASCADE_BOTH which tells it to update both the following
  #   and previous cards. If it is CASCADE_FORWARDS or CASCADE_BACKWARDS only
  #   cards in the direction specified will be updated. This is to stop cards
  #   infinitely updating each other.
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

# Provides an API to the cardListItem directive that allows cards to
# be added/removed from the list. It manages an instance of a CardList
# and ensures that rendering is up to date.
class CardListController
  this.$inject = ['annotator']
  constructor: (annotator) ->
    vm = this
    list = createCardList()
    count = 0

    vm.registerItem = (id, anchorTop, elem, index) ->
      card = new Card(elem, anchorTop)
      list.splice(index, 0, card)

    vm.draw = (index) ->
      list.anchor(list[index])
      list.draw(annotator.scrollY)

# A simple controller directive that sits on the top of the stream-list and
# provides a controller for child cardListItems to interact with.
cardList = [->
  controller: 'CardListController'
  controllerAs: 'vm'
  require: []
  scope: true
]

# An individual card list item. This registers itself with the parent
# cardList and notifies the list controller of changes to it's annotation
# position/dimensions etc.
cardListItem = ['$parse', ($parse) ->
  linkFn = (scope, elem, attrs, [cardList]) ->
    annotation = $parse(attrs.cardListItem)(scope)
    if annotation?
      top = annotation.target?[0]?.pos.top || 0
      cardList.registerItem(annotation.id, top, elem, scope.$index)

    scope.$watch '$index', (val) ->
      # Use this to update the index of cards should they be re-ordered

    scope.$watch (-> elem.outerHeight()), ->
      # A card has been expanded/collapsed so redraw.
      cardList.draw(scope.$index)

  link: linkFn
  require: ['^cardList']
  scope: true
]

angular.module('h.directives')
.controller('CardListController', CardListController)
.directive('cardList', cardList)
.directive('cardListItem', cardListItem)
