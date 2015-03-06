#!/usr/bin/env node

var fs = require('fs')
  , argv = require('yargs').argv
  , http = require('http')
  , jade = require('jade')
  , static = require('node-static')
  , pathUtil =require('path')
  , srcpath = pathUtil.resolve(argv.in)
  , outpath = pathUtil.resolve(argv.out)
  , jadeRe = /\.jade$/
  , jadeIgnores = /\.(include|extend)\.jade$/
  , port = parseInt(argv.port) || 8080
  , fileServer = new static.Server(outpath || '.')
  , cson = require("./cson")

process.chdir(outpath)

var buildLocals = function (jadeString, filename) {
  // This regex matches the form: //-someVar = require("../some-file.cson")
  // and tries to read that given file as JSON or CSON
  var RE = /\/\/\-(\w+)\s*=\s*require\(['"]([^'"]+)['"]\)/g;
  var match
  var locals = {}
  while (match = RE.exec(jadeString), match != null) {
    var requiredFile = pathUtil.resolve(pathUtil.dirname(filename), match[2])
    locals[match[1]] = cson.parse(fs.readFileSync(requiredFile, "utf8"))
  }
  return locals
}

function renderJade (filename, outfilename) {
  try {
    var jadeContents = fs.readFileSync(filename, "utf8")
    var locals = buildLocals(jadeContents, filename)
    
    locals.filename = filename.replace(jadeRe, '')
    locals.pretty = true
    fs.writeFileSync(
      outfilename,
      jade.renderFile(filename, locals)
    )
    console.log("Wrote: " + outfilename)
  } catch (error) {
    console.error("Jade Error: ")
    console.error(error)
  }
}

var allJadeFiles = null;

function watchForCompile (filename, outfilename) {
  fs.watch(filename, function () {
    if (!jadeRe.exec(filename) || jadeIgnores.exec(filename)) {
      for (var i = 0; i < allJadeFiles.length; i++) {
        renderJade(allJadeFiles[i].in, allJadeFiles[i].out)
      }
    } else {
      renderJade(filename, outfilename)
    }
  })
}

// Read `in` directory recursively
require('recursive-readdir')(srcpath, function (err, files) {
  allJadeFiles = files.filter(function (element) {
    return !element.match(jadeIgnores) && element.match(jadeRe)
  }).map(function (originalName) {
    return {
      in : originalName,
      out: originalName.replace(srcpath, outpath).replace(jadeRe, ".html")
    }
  })

  // Files is an array of filename
  for (var i = 0; i < files.length; i++) {
    try {
      filename = files[i];
      outfilename = filename.replace(srcpath, outpath).replace(jadeRe, ".html");
      watchForCompile(filename, outfilename)
      if (!jadeIgnores.exec(filename) && jadeRe.exec(filename))
        renderJade(filename, outfilename)
    } catch (error) {
      console.log(error)
    }
  }
})


fileServer.serveDir = function (pathname, req, res, finish) {
  fs.readdir(pathname, function(err, results) {
    res.writeHead(200, {'Content-Type': 'text/html'})
    res.end(jade.render('pre\n if pathname.length\n  a(href="../") ..\n  br\n each file in results\n  a(href=pathname+"\/"+file)=file\n  br', {
      results: results,
      pathname: req.url.length === 1 ? '' : req.url
    }))
    finish(200, {})
  })
}

http.createServer(function (req, res) {
  req.addListener('end', function () {
    fileServer.serve(req, res)
  }).resume()
}).listen(port)
