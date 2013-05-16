class Controller

  _Template: (name) -> new Template[name](this)
  _View: (name) -> new Template[name](this)
  _Model: (name) -> new Template[name](this)

module.exports = Controller
