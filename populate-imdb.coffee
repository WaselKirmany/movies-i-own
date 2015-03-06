imdb = require 'imdb-api'
async = require 'async'
love = require 'cheerio' 

fs = require "fs"
path = require "path"
request = require('request')
dir = process.argv[2] || "./"
arr = fs.readdirSync(dir)
arr = arr.sort()

nameRE = /([_\-\[\]\(\)]+|\.mkv|t\d+|Unrated|Diamond|Edition|Disc[_\- ]\d|title\d+|movies?)/ig
titleIdRE = /tt(\d+)/

makeSearchURL = (term) ->
  "http://m.imdb.com/find?q=" + term.replace(/[ _)(]+/g, "+")

makeMovieURL = (id) ->
  "http://m.imdb.com/title/tt" + id + "/"

movies = {}

for fileName in arr
  entryName = fileName.replace(nameRE, " ").trim().toLowerCase()
  if not movies[entryName]?
    movies[entryName] = { files: [] }

  movies[entryName].files.push fileName

async.eachSeries( Object.keys(movies)
  , (entryName, done) ->
    console.log "Looking for " + entryName
    year = entryName.match(/\d{4}/)
    
    request makeSearchURL(entryName), (error, response, body) ->
      if !error and response.statusCode is 200
        $searchResults = love.load body
        
        elem = $searchResults(".posters .poster>.retina-capable")
        titleId = null
        useElem = elem.first()
        elem.each (index, elem2) ->
          elem2 = $searchResults elem2
          if year?
            if elem2.parent().find(".title").text().indexOf(year) isnt -1
              useElem = elem2
              return false

            if index > 5
              console.error "Couldn't find in results"
              useElem = null
              return false

        if useElem?
          titleId = useElem.parent().find("a").attr("href")
        
        if !titleId
          console.log "Error finding " + entryName
          done()

        else
          id = titleId.match(titleIdRE)[1]
          url = makeMovieURL(id)
          request url, (error, response, body) ->
            if !error and response.statusCode is 200
              $entryPage = love.load body
              movies[entryName].href = url.replace("m.imdb", "imdb")
              movies[entryName].img = $entryPage("img.media-object").first().attr("src")
              movies[entryName].title = $entryPage(".media-body h1").text().replace(/[\s\n]+/g, " ").trim()
              movies[entryName].rating = $entryPage("#ratings-bar").text().match(/([\d\.]+)\//)[1]
              movies[entryName].duration = $entryPage(".infobar time").text().trim()
              done()

            else
              throw "Strange error"

      else
        console.log "Error trying to locate \"" + entryName + "\""
        console.error error
        done()
  , ->
    fs.writeFileSync "./movies.json", JSON.stringify(movies, null, 2)
)
#fs.writeSync "files.txt", arr.join("\n")