class App.Routers.Router extends Backbone.Router

  initialize: ->
    new App.Views.DefaultHelpers
    new App.Views.DropdownMenu if $('.dropdown-menu').length > 0
    new App.Views.Pickadate
    new App.Views.Editor

  routes:
    'admin': 'admin'

  admin: ->
    true
