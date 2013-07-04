
"Object"-based JSON converts registered types to a notation like `{$Date: "..."}`

Array JSON notation is not used because there are no arrays in JavaScript (JavaScript Arrays can have arbitrary keys, missing values and are implemented as hash tables). Instead Arrays become more verbose but more robust: `{$Array: {0: 'first', 1: 'second'}}`.

register a new type with OJSON.register <constructor>

if the type implements a class method fromJSON, it'll be used as a factory. for example:

   var Foo = function (value) { this._value = value; };
   Foo.prototype.toJSON = function() {  return this._value; };
   Foo.fromJSON = function(arg) { return new this(arg); };
   OJSON.register(Foo);

if the type does not implement fromJSON, its JSON representation (either from toJSON or an object containing all its keys) is passed to the constructor:

   // when restored, will call new Foo(value)
   var Foo = function (value) { this._value = value; };
   Foo.prototype.toJSON = function() {  return this._value; };
   OJSON.register(Foo);

This works well for other types. Date, for instance, has a toJSON(), whose value can be passed to the constructor to re-create it.

Note that the reference mechanism requires that objects are defined before they're referenced, so it's sensitive to the order of key traversal in the parse function

Also note that you can't serialize values that are set to void 0. It's possible to send it, but because JSON.parse treats a void 0 return value from its reviver as "remove from the object", reviving void 0 values would require re-implementing JSON.parse.


can register custom names with the form {name: constructor}. This adds a
`_ojson` property to the constructor. For custom names, prefer starting
with an uppercase (no $ prefix necessary)
