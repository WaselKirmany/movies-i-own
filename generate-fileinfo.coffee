
fs = require "fs"
path = require "path"

fileNameExcludesRE = /([_\-\[\]\(\)]+|\.mkv|t\d+|Unrated|Diamond|Edition|Disc[_\- ]\d|title\d+|movies?)/ig

# Collect movies from folders
directories = process.argv.slice(2)
if directories.length is 0
  directories = ["./"]
filesInfo = {}
for dir in directories
  # generate information about each movie,
  # this includes whether or not it is a DVD with menus, a BDRip, a DVDRip, or MP4/(menuless)
  for fileName in fs.readdirSync(dir)
    movieName = fileName.replace(fileNameExcludesRE, " ").trim().toLowerCase()
    filePath = path.resolve(dir, fileName)
    
    if filesInfo[movieName]?
      filesInfo[movieName].files.push filePath

    else
      info = {
        files: [filePath]
        movieName
        format: null
        hasMenus: false
      }
      fileStats = fs.lstatSync filePath
      if fileStats.isDirectory()
        # could be dvd with menus, a series, or multiple titles BDRip
        movieDirFiles = fs.readdirSync filePath
        isDVDWithMenus = movieDirFiles.indexOf "title.IFO" > -1
        if isDVDWithMenus
          info.format = "DVDRip+"
          info.hasMenus = true
        else
          info.format = "folder"

      else
        if fileStats.size > 1e6
          info.format = "BDRip"
        else
          info.format = "DVDRip"

        if path.extname(filePath) is ".mkv"
          info.hasMenus = true

      filesInfo[movieName] = info

fs.writeFileSync("./_fileinfo.js", "module.exports = " + JSON.stringify(filesInfoArr, null, 2) + ";","utf8")