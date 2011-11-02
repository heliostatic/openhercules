App =
  # Config
  lists: null
  appId: "#app"
  backbone: {}
  selection: (item) ->
    if (item)
      @selected = item
    else if !@selected
      @selected = App.root.children.first()
    @selected

class App.backbone.List extends Backbone.Model      
  change: -> @save()

  changeProperties: (properties) ->
    @set($.extend properties, items: App.root.asJson().children)
    @propertiesView.render()
  
  updateItems: ->
    @set items: App.root.asJson().children
  
  isEmpty: ->
    @get('items').length == 1 && @get('items')[0].body == ""
    

class App.backbone.Lists extends Backbone.Collection
  model: App.backbone.List
  url:   "/lists"

class App.backbone.Item extends Backbone.Model
  initialize: ->
    if @get "parent"
      @parent = @get("parent");
      @unset 'parent', silent: true
    else if App.root
      @parent = App.root
      @parent.addChild(this)
    
    if !@get("body")
      @set { body:"" }, { silent:true }
    
    @children = new App.backbone.ItemChildren;
    if @get("children")
      for child in @get("children")
        child["parent"] = @
        @addChild new App.backbone.Item(child)
    
  events:
    'change': 'change'
  
  asJson: ->
    json = @toJSON()
    json.children = this.children.map (child) -> child.asJson()
    json
  
  updateList: ->
    App.mainList.updateItems()
  
  change: ->
    @view.setClasses()
    @view.setBody()
  
  
  # children
  addChild: (child) -> 
    @children.add child
  
  removeChild: (child) -> 
    @children.remove child
  
  # move
  insertBefore: (ref) ->
    ref.parent.children.insertBefore @, ref
  
  insertAfter: (ref) ->
    ref.parent.children.insertAfter @, ref
  
  moveUp: ->
    if @previousSibling()
      prev = @previousSibling()
      $(@view.el).insertBefore prev.view.el
      @parent.removeChild @
      @insertBefore prev
  
  moveDown: ->
    if @nextSibling()
      next = @nextSibling()
      $(@view.el).insertAfter next.view.el
      @parent.removeChild @
      @insertAfter next
  
  # selecting
  select: ->
    if App.selection()
      App.selection().deselect()
      
    App.selection @
    @view.select()
  
  deselect: ->
    App.selection null
    @view.deselect()
  
  # siblings
  next: ->
    flat = App.root.children.flatten()
    i = flat.indexOf @
    flat[i+1]
  
  previous: ->
    flat = App.root.children.flatten()
    i = flat.indexOf @
    flat[i-1]
  
  previousSibling: ->
    @parent.children.before @
  
  nextSibling: ->
    return @parent.children.after @
    
  # parents
  indent: ->
    if @previousSibling()
      oldParent = @parent
      @setParent @previousSibling()
      oldParent.removeChild @
      @parent.addChild @
      $(@parent.view.childrenView.el).append @view.el
      @save()
  
  outdent: ->
    if @parent != App.root
      oldParent = @parent
      @setParent @parent.parent
      oldParent.removeChild @
      @insertAfter oldParent
      $(@view.el).insertAfter oldParent.view.el
      @save()
  
  setParent: (parent) ->
    @parent = parent
    @set 'parent_id': parent.id
  
  parents: ->
    p = []
    current_parent = @parent;
    while current_parent != App.root
      p.push current_parent
      current_parent = current_parent.parent
    p
  
  # goodbye
  remove: ->
    prev = @previous()
    if prev
      prev.select()

    $(@view.el).remove()
    @parent.children.remove @
    @updateList()
  
  # status
  toggleStatus: ->
    if @get('status') == 'complete'
      @setIncomplete()
    else
      @setComplete()
  
  setIncomplete: ->
    @set 'status':'incomplete'
    for parent in @parents()
      parent.setIncomplete()
    @view.status.attr 'checked', false
    @view.setClasses()
    @save()
  
  setComplete: ->
    @set 'status':'complete'
    for child in @children.flatten()
      child.setComplete()
      
    @view.status.attr 'checked', true
    @view.setClasses()
    @save()
  
  save: ->
    @updateList()

class App.backbone.ItemChildren extends Backbone.Collection
  model: App.backbone.Item
  before: (item) ->
    @inRelationToItem item, -1

  after: (item) ->
    @inRelationToItem item, 1

  insertBefore: (toInsert, ref) ->
    toInsert.parent.removeChild toInsert
    @add toInsert
    @models.pop()
    i = @indexOf(ref)
    @models.splice i, 0, toInsert

  insertAfter: (toInsert, ref) ->
    toInsert.parent.removeChild toInsert
    @add toInsert
    @models.pop()
    i = @indexOf(ref)
    @models.splice i + 1, 0, toInsert

  inRelationToItem: (item, relativeIndex) ->
    nextItem = @at(@indexOf(item) + relativeIndex)
    nextItem

  flatten: ->
    results = []
    @each (item) ->
      results.push item
      if item.children.length
        _.each item.children.flatten(), (child) ->
          results.push child

    results
    
class App.backbone.ItemFormView extends Backbone.View
  tagName: "form"
  template: _.template "<input type='text' value='' />"
  events: 
    submit: "submit"
    keydown: "handleKey"
    "keydown input": "handleInputKey"
    "blur input": "stopEditing"

  submit: ->
    @stopEditing()
    App.mainList.view.newItem()
    false
    
  stopEditing: ->
    val = @$("input").val()
    @model.set body: val
    @model.save()
    @model.view.switchToShow()

  handleKey: (event) ->
    keyCode = event.keyCode.toString()
    if keyCode == "27"
      @stopEditing()
    else if keyCode == "13"
      @stopEditing()
      App.mainList.view.newItem()

  handleInputKey: (event) ->
    keyCode = event.keyCode.toString()
    if keyCode == "27"
      @stopEditing()
      false
    else if keyCode == "38"
      prev = App.selection().previous()
      if prev
        @stopEditing()
        prev.select()
        prev.view.switchToForm()
      false
    else if keyCode == "40"
      next = App.selection().next()
      if next
        @stopEditing()
        next.select()
        next.view.switchToForm()
      false

  render: ->
    $(@el).html @template()
    @$("input:first").val @model.get("body")
    this

class App.backbone.ItemView extends Backbone.View
  tagName: "li"
  template: _.template("<div class='item'><div class='body'></div></div>")
  initialize: ->
    @model.view = this

  events: 
    "change input[type=\"checkbox\"]:first": "changeStatus"
    "click .item.selected": "preventFurtherClicks"
    "click .item:first": "click"
    "dblclick .item:first": "switchToForm"

  changeStatus: ->
    if @status.is(":checked")
      @model.setComplete()
    else
      @model.setIncomplete()

  click: ->
    @model.select()
    
  preventFurtherClicks: (e) ->
    e.stopImmediatePropagation()

  dblclick: ->
    @switchToForm()

  setClasses: ->
    @item.attr "class", "item"
    @item.addClass @model.get("status")
    @item.addClass @model.get("item_type")
    @item.addClass "selected"  if App.selected == @model

  select: ->
    @item.addClass "selected"

  deselect: ->
    @form.submit() if @$("form").length
    @item.removeClass "selected"

  setBody: ->
    @body.html @model.get("body") + "&nbsp;"

  render: ->
    that = this
    $(@el).html @template(@model.toJSON())
    @item = $(@el).children(".item")
    @body = @item.children(".body")
    @setBody()
    @status = $("<input type='checkbox' />")
    if @model.get("status") == "complete"
      @status.attr "checked", true
    else
      @status.attr "checked", false
    $(@item).prepend @status
    @childrenView = new App.backbone.ItemChildrenView(model: @model)
    $(@el).append @childrenView.render().el
    @setClasses()
    this

  switchToForm: ->
    @form = new App.backbone.ItemFormView(model: @model)
    @body.replaceWith @form.render().el
    $(@form.el).find("input").focus()

  switchToShow: ->
    @setBody()
    $(@form.el).replaceWith @body
    @model.select()

class App.backbone.ItemChildrenView extends Backbone.View
  tagName: "ul"
  className: "children"
  render: ->
    that = this
    @model.children.each (child) ->
      lv = new App.backbone.ItemView(model: child)
      $(that.el).append lv.render().el

    this

class App.backbone.ListPropertiesView extends Backbone.View  
  render: ->
    @$(".name").text(@model.get("name"))
    $(".list-#{@model.get("id")} a").text(@model.get("name"))
    @$(".description").text(@model.get("description"))
    this

class App.backbone.ListPropertiesFormView extends Backbone.View  
  events:
    "click .primary": "submit"
    "form submit": "submit"
    "click .cancel": "cancel"
  
  render: ->
    @$(".name").val(@model.get("name"))
    @$(".description").val(@model.get("description"))
    this
  
  submit: ->
    @model.changeProperties
      name: @$(".name").val()
      description: @$(".description").val()
    $("#properties-form").modal("hide")
    false
  
  cancel: ->
    @render()
    $("#properties-form").modal("hide")

class App.backbone.ListView extends Backbone.View
  tagName: "ul"
  className: "item-list"
  
  initialize: ->
    _.bindAll @, "selectPrevious", "selectNext", "switchItem", "toggleStatus", "moveSelectionUp", "moveSelectionDown", "indentItem", "outdentItem", "newItem", "deleteItem"

  selectPrevious: ->
    if not App.selected and App.selection()
      App.selection().select()
    else
      App.selection()?.previous()?.select()
    false

  selectNext: ->
    if not App.selected and App.selection()
      App.selection().select()
    else App.selection().next().select()  if App.selection() and App.selection().next()
    false

  switchItem: ->
    App.selection().view.switchToForm()

  toggleStatus: ->
    App.selection().toggleStatus()
    false

  moveSelectionUp: (event) ->
    App.selection().moveUp()
    false

  moveSelectionDown: (event) ->
    App.selection().moveDown()
    false

  indentItem: ->
    App.selection().indent()

  outdentItem: ->
    App.selection().outdent()

  newItem: (placement) ->
    selection = App.selection()
    if selection
      parent = selection.parent
    else
      parent = App.root
    item = new App.backbone.Item(parent: parent)
    itemView = new App.backbone.ItemView(model: item)
    itemView.render()
    if selection
      if placement == "previous"
        item.insertBefore selection
        $(item.view.el).insertBefore selection.view.el
      else
        if selection.children.size() > 0
          selection = selection.children.first()
          item.insertBefore selection
          $(item.view.el).insertBefore selection.view.el
        else
          if placement == "indent"
            item.insertAfter selection
            item.indent()
          else # insert after
            item.insertAfter selection
            $(item.view.el).insertAfter selection.view.el
    else
      $(@el).append itemView.el
    item.select()
    _.defer ->
      App.selection().view.switchToForm()

  deleteItem: ->
    App.selection().remove()
    false

  render: ->
    that = this
    @collection.each (item) ->
      unless item.get("parent_id")
        lv = new App.backbone.ItemView(model: item)
        $(that.el).append lv.render().el

    this

App.keyBindings = ->
  $(document).bind "keydown", "up", App.mainList.view.selectPrevious
  $(document).bind "keydown", "down", App.mainList.view.selectNext
  $(document).bind "keydown", "esc", App.mainList.view.switchItem
  $(document).bind "keydown", "ctrl+up", App.mainList.view.moveSelectionUp
  $(document).bind "keydown", "ctrl+down", App.mainList.view.moveSelectionDown
  $(document).bind "keydown", "space", App.mainList.view.toggleStatus
  $(document).bind "keydown", "return", ->
    App.mainList.view.newItem()

  $(document).bind "keydown", "ctrl+return", ->
    App.mainList.view.newItem "indent"

  $(document).bind "keydown", "shift+return", ->
    App.mainList.view.newItem "previous"

  $(document).bind "keydown", "backspace", App.mainList.view.deleteItem
  $(document).bind "keydown", "del", App.mainList.view.deleteItem
  $(document).bind "keydown", "x", App.mainList.view.indentItem
  $(document).bind "keydown", "z", App.mainList.view.outdentItem
  $(document).bind "keydown", "p", ->
    $("#project").focus()

App.setup = (list) ->
  $ ->
    App.setupList list
    $(App.appId).append App.mainList.view.render().el
    App.keyBindings()
    App.mainList.view.selectNext()
    App.mainList.view.switchItem() if App.mainList.isEmpty()

App.setupList = (list) ->
  App.lists = new App.backbone.Lists([ 
    id: list._id
    name: list.name
    description: list.description
    items: list.items
  ])
  App.mainList = App.lists.at(0)
  App.setupItems list.items
  App.mainList.view = new App.backbone.ListView(collection: App.root.children)
  App.mainList.propertiesView = new App.backbone.ListPropertiesView(model: App.mainList, el: $("#properties"))
  App.mainList.propertiesFormView = new App.backbone.ListPropertiesFormView(model: App.mainList, el: $("#properties-form"))

App.setupItems = (items) ->
  App.root = new App.backbone.Item()
  _.each items, (item) ->
    new App.backbone.Item(item)

$ ->
  $(".cookie-user").click ->
    confirm "Are you sure? You will not be able to recover your data unless you modify your account first."
  $("#new").bind "shown", -> $("#new .name").focus()
  $("#new .primary").click -> $("#new form").submit()
  $("#new .cancel").click -> $("#new").modal("hide")

window.App = App