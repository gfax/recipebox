recipebox
=========

Sinatra app for [r.gfax.ch](http://r.gfax.ch). This app caches files written in [textile](http://redcloth.org/try-redcloth/) and markdown for a quick database-less website -- written for those that want a small site or blog with git version control. This app uses [slim](http://slim-lang.com/) for templating and purebred sass syntax for the stylesheets.

###Up and Running

Modify `unicorn.rb` to suit your needs then run the commands:

    bundle install
    bundle exec unicorn -c unicorn.rb

Modify `recipebox.rb` to set your app name and environment.


###Example Page

See `views/recipes` for folder hierarchy and examples using textile. Since I personally don't use markdown, here is an example markdown page:

    <!-- 1267666404 (This line is for adding a unix timestamp to use as a post date, but completely optional.) -->
    ## Markdown Soup

    * 1 tsp salt
    * 1 Tbsp ruby
    * 1 magic, zest and juice

    + Combine ingredients
    + ???
    +  Profit

Copy the code above into a new file and save as `views/recipes/markdown-soup.md` and let the main page auto-sort the new recipe for you.

###Caching and Nginx

When in a production environment, the app will write html files of the index and sub-pages to a folder called `.cache` in the app root. The sass handler should take care of the stylesheets for you automatically. Otherwise, drop static css files in the public folder. Though very rudimentary, this will bypass routing through unicorn for repeating requests, and you can clear the cache by deleting `.cache` or any file in it.
Here's a basic config pointing to the cache folder in Nginx:

    ### Recipebox App ###
    upstream unicorn_recipebox {
      server unix:/srv/recipebox/unicorn.sock
        fail_timeout=0;
    }
    server {
      access_log  logs/recipebox.access_log main;
      error_log   logs/recipebox.error_log info;
      listen 80;
      server_name r.gfax.ch;
      root /srv/recipebox;
      location @app {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_redirect off;
        # Pass to the upstream unicorn server mentioned above.
        proxy_pass http://unicorn_recipebox;
      }
      location = / {
        try_files /.cache/index.html /public/index.html @app;
      }
      location / {
        try_files /.cache/$uri /.cache/$uri.html /public/$uri /public/$uri.html @app;
      } 
    } 

Yeeeeeppp.
