(function(){
var d=null,e,f;Object.create==d&&(Object.create=function(a){var b;b=function(){};b.prototype=a;return new b});Object.keys==d&&(Object.keys=function(a){var b,c;c=[];for(b in a)({}).hasOwnProperty.call(a,b)&&c.push(b);return c});Array.isArray==d&&(Array.isArray=function(a){return""+a!==a&&"[object Array]"==={}.toString.call(a)});if((e=Array.prototype).some==d)e.some=function(a){var b,c,g;c=0;for(g=this.length;c<g;c++)if(b=this[c],a(b))return!0;return!1};
if((f=String.prototype).trim==d){var h;h=/^\s+|\s+$/g;f.trim=function(){return this.replace(h,"")}}Date.now==d&&(Date.now=(new Date).getTime());"Array"!==Array.name&&(Array.name="Array",Object.name="Object",Date.name="Date",Number.name="Number",String.name="String");
})();
