/*
 * MODIFIED
 
Copyright (c) 2009 Bruce Williams

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

var fs   = require('fs'),
    os   = require('os'),
    path = require('path'),
    cnst = require('constants');

/* HELPERS */

var RDWR_EXCL = cnst.O_CREAT | cnst.O_TRUNC | cnst.O_RDWR | cnst.O_EXCL;

var environmentVariables = ['TMPDIR', 'TMP', 'TEMP'];

var generateName = function(rawAffixes, defaultPrefix) {
  var affixes = parseAffixes(rawAffixes, defaultPrefix);
  var now = new Date();
  var name = affixes.name || [affixes.prefix,
              now.getYear(), now.getMonth(), now.getDate(),
              '-',
              process.pid,
              '-',
              (Math.random() * 0x100000000 + 1).toString(36),
              affixes.suffix].join('');

  return path.join(affixes.dir, name);
};

var parseAffixes = function(rawAffixes, defaultPrefix) {
  var affixes;
  if(rawAffixes) {
    switch (typeof(rawAffixes)) {
    case 'string':
      affixes = {};
      affixes.prefix = rawAffixes;
      break;
    case 'object':
      affixes = rawAffixes;
      break
    default:
      throw("Unknown affix declaration: " + affixes);
    }
  } else {
    affixes = {};
    affixes.prefix = defaultPrefix;
  }

  if (affixes.dir == null) affixes.dir = exports.dir;

  return affixes;
};

/* EXIT HANDLERS */

/*
 * When any temp file or directory is created, it is added to filesToDelete
 * or dirsToDelete. The first time any temp file is created, a listener is
 * added to remove all temp files and directories at exit.
 */
var exitListenerAttached = false;
var filesToDelete = [];
var dirsToDelete = [];

var deleteFileOnExit = function(filePath) {
  attachExitListener();
  filesToDelete.push(filePath);
};

var deleteDirOnExit = function(dirPath) {
  attachExitListener();
  dirsToDelete.push(dirPath);
};

var attachExitListener = function() {
  if (!exitListenerAttached) {
    process.addListener('exit', cleanup);
    exitListenerAttached = true;
  }
};

var cleanupFiles = function() {
  for (var i=0; i < filesToDelete.length; i++) {
    try {
    fs.unlinkSync(filesToDelete[i]);
    }
    catch (rmErr) { /* removed normally */ }
  }
};

var cleanupDirs = function() {
  for (var i=0; i < dirsToDelete.length; i++) {
    try {
    fs.rmdirSync(dirsToDelete[i]);
    }
    catch (rmErr) { /* removed normally */ }
  }
};

var cleanup = function() {
  cleanupFiles();
  cleanupDirs();
};

/* DIRECTORIES */

var mkdir = function(affixes, callback) {
  if (typeof affixes == 'function') {
    callback = affixes;
    affixes = void 0;
  }

  var dirPath = generateName(affixes, 'd-');
  fs.mkdir(dirPath, 0700, function(err) {
    if (!err) {
      deleteDirOnExit(dirPath);
    }
    if (callback)
      callback(err, dirPath);
  });
};
var mkdirSync = function(affixes) {
  var dirPath = generateName(affixes, 'd-');
  fs.mkdirSync(dirPath, 0700);
  deleteDirOnExit(dirPath);
  return dirPath;
};

/* FILES */

var open = function(affixes, callback) {
  if (typeof affixes == 'function') {
    callback = affixes;
    affixes = void 0;
  }

  var filePath = generateName(affixes, 'f-')
  fs.open(filePath, RDWR_EXCL, 0600, function(err, fd) {
    if (!err)
      deleteFileOnExit(filePath);
    if (callback)
      callback(err, {path: filePath, fd: fd});
  });
};

var openSync = function(affixes) {
  var filePath = generateName(affixes, 'f-')
  var fd = fs.openSync(filePath, RDWR_EXCL, 0600);
  deleteFileOnExit(filePath);
  return {path: filePath, fd: fd};
};

var createWriteStream = function(affixes) {
  var filePath = generateName(affixes, 's-')
  var stream = fs.createWriteStream(filePath, {flags: RDWR_EXCL, mode: 0600});
  deleteFileOnExit(filePath);
  return stream;
};

var symlink = function (src, affixes, callback) {
  if (typeof affixes == 'function') {
    callback = affixes;
    affixes = void 0;
  }

  var filePath = generateName(affixes, 'l-')
  fs.symlink(src, filePath, function (err) {
    if (!err) deleteFileOnExit(filePath);
    if (callback) callback(err, filePath);
  });
};

var symlinkSync = function (src, affixes) {
  var filePath = generateName(affixes, 'l-')
  return fs.symlinkSync(src, filePath);
};

/* EXPORTS */
exports.dir               = os.tmpDir();
exports.mkdir             = mkdir;
exports.mkdirSync         = mkdirSync;
exports.open              = open;
exports.openSync          = openSync;
exports.symlink           = symlink;
exports.symlinkSync       = symlinkSync;
exports.path              = generateName;
exports.cleanup           = cleanup;
exports.createWriteStream = createWriteStream;


