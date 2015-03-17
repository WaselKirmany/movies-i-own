async = require 'async'
cheerio = require 'cheerio' 
request = require 'request'

imdbURLTitleIdRE = /tt(\d+)/

makeSearchURL = (term) ->
  "http://m.imdb.com/find?q=" + term.replace(/[ _)(]+/g, "+")

makeMovieURL = (id) ->
  "http://m.imdb.com/title/tt" + id + "/"

movies = require './_fileinfo.js'

async.eachSeries( Object.keys(movies)
  , (movieName, done) ->
    console.log "Looking for " + movieName
    releaseYear = movieName.match(/\d{4}/)

    request makeSearchURL(movieName), (error, response, body) ->
      if !error and response.statusCode is 200
        $searchResults = cheerio.load body
        
        searchResultElems = $searchResults(".posters .poster")
        foundMovieElem = null
        if releaseYear?
          searchResultElems.each (index, movieElem) ->
            movieElem = $searchResults movieElem
            if index > 5
              return false

            else if movieElem.find(".title").text().indexOf(releaseYear) isnt -1
              foundMovieElem = movieElem
              return false

        else
          foundMovieElem = searchResultElems.find(">.retina-capable").first().parent() 

        if not foundMovieElem?
          console.error "Error finding " + movieName
          done()

        else
          imdbMovieURL = foundMovieElem.find("a").attr("href")

          id = imdbMovieURL.match(imdbURLTitleIdRE)[1]
          url = makeMovieURL(id)
          request url, (error, response, body) ->
            if !error and response.statusCode is 200
              $entryPage = cheerio.load body
              title = $entryPage(".media-body h1").text().replace(/[\s\n]+/g, " ").trim()
              m = movies[movieName]
              m.href = url.replace("m.imdb", "imdb")
              m.title = title
              m.rating = $entryPage("#ratings-bar").text().match(/([\d\.]+)\//)[1]
              m.duration = $entryPage(".infobar time").text().trim()
              img = $entryPage("img.media-object").first().attr("src")
              ext = path.extname(img)
              m.img = './images/' + title.replace(/[:\\\/\*\^~`?]+/g, "_") + ext
              request.get(img).pipe(fs.createWriteStream(m.img))
              done()

            else
              throw "Error loading page"

      else
        console.log "Error trying to locate \"" + movieName + "\""
        console.error error
        done()
  , ->
    fs.writeFileSync "./movies.json", JSON.stringify(movies, null, 2)
)
