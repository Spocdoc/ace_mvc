require '../../db/client'
Template = require '../../mvc/template'
View = require '../../mvc/view'
Controller = require '../../mvc/controller'
global.Ace = require '/Users/mikerobe/Documents/Local/Dropbox/Documents/all/_+Documents/_Projects/_javascript/ace mvc/lib/ace'
global.Template = Template
global.View = View
global.Controller = Controller
Template.add 'body', '''<body></body>'''
Template.add 'layout', '''<html><head><title></title></head><body id="content"></body></html>'''
Template.add 'root', '''<p>hello world</p>'''
View.add 'body', require '../../../app/body/view'
View.add 'root', require '../../../app/root/view'
Controller.add 'body', require '../../../app/body/controller'
Controller.add 'root', require '../../../app/root/controller'