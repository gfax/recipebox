recipebox
=========

Sinatra app for [r.gfax.ch](http://r.gfax.ch). App uses [slim](http://slim-lang.com/) for templating, and renders either [textile](http://redcloth.org/try-redcloth/) or markdown for the recipe pages. See `views/recipes` for folder hierarchy.

Example markdown page (even though I pesonally find textile much more intuitive and flexible):

    <!-- 1267666404 (This line is for unix timestamp to use as a post date, but completely optional.) -->
    ## Markdown Soup

    * 1 tsp salt
    * 1 Tbsp ruby
    * 1 magic, zest and juice

    + Combine ingredients
    + ???
    +  Profit

Drop in `recipes/soup-and-stew/markdown-soup.md` and let the index page auto-sort for you.
