# coding: UTF-8
class RecipeBox < Sinatra::Base

  ### Configuration ###
  SiteName = '#gfax - Recipebox'
  SiteTitle = 'gfax - Recipebox'
  PagesFolder = File.dirname(__FILE__) + '/views/recipes/'

  #set :environment, :production # enables caching

  set :markdown,
    :layout_engine => :slim,
    :layout => :layout
  set :textile,
    :layout_engine => :slim,
    :layout => :layout

  def cache(text)
    # Cache rendered pages in a production environment.
    # Requests to / should be cached as index.html.
    urn = request.path_info == "/" ? 'index' : request.path_info
    # Don't cache pages with query strings.
    unless urn =~ /\?/
      urn << '.html' unless urn == '/atom.xml'
      # Put all cached files in a subdirectory called '.cache'.
      path = File.join(File.dirname(__FILE__), '.cache', urn)
      # Create the directory if it doesn't exist.
      FileUtils.mkdir_p(File.dirname(path))
      # Write the text passed to the path.
      File.open(path, 'w') { |f| f.write( text ) } unless File.exists?(path)
    end
    return text
  end

  def readmeta(file=nil)
    return {} unless file
    n = PagesFolder.length
    meta = {}
    begin
      page = Preamble.load(file)
      meta = page.metadata
      meta['body'] = page.content
      meta['tags'] = [*meta['tags']] if meta['tags']
    rescue RuntimeError
    end
    meta['filepath'] = file[n..-1].chomp File.extname(file)
    if meta['date']
      # Extract date from file timestamp and convert unix timestamps.
      t = Time.at(meta['date'].to_s.to_i)
      meta['date'] = t unless t.year <= 1969
      # Check if file timestamp is at least 24 hours newer than date meta.
      if t.to_i < File.new(file).ctime.to_i - 88000
        meta['updated'] = File.new(file).ctime
      end
    else
      meta['date'] = File.new(file).ctime
    end
    unless meta['title']
      meta['title'] = File.basename(file, File.extname(file))
      meta['title'] = meta['title'].gsub(/(\-|_)/,' ').split.map(&:capitalize)*' '
    end
    return meta
  end

  def hash_pages(folder=PagesFolder, opts={})
    sort = opts[:sort_by] || 'title'
    # Array of category folders.
    a = Dir.glob(folder + '**/').map { |f| f.sub(folder, '').chop }
    # Remove root directory. We'll manually add this on at the end.
    a.shift
    # Create a hash to sort pages in.
    h = {}
    # Start with pages in each sub-directories.
    a.sort.each do |e|
      h[e] = Dir[folder + e + '/*'].select { |f| not File.directory? f }
      # Collect page data into sub-hashes.
      h[e].map! { |filepath| readmeta(filepath) }
      h[e].sort_by! { |h| h[sort] }
    end
    # Category for pages in the root directory:
    h['root'] = Dir[folder + '*'].select { |f| not File.directory? f }.sort
    h['root'].map! { |filepath| readmeta(filepath) }
    h['root'].sort_by! { |h| h[sort] }
    return h
  end

  def uri
    case request.port
      when 80 then 'http://' + request.host
      when 443 then 'https://' + request.host
      else 'http://' + request.host_with_port
    end
  end

  class CoffeeHandler < Sinatra::Base
    set :views, Dir.pwd + '/views/coffeescript'
    get '*.js' do
      filename = params[:splat].first
      coffee filename.to_sym
    end
  end

  class SassHandler < Sinatra::Base
    set :views, Dir.pwd + '/views/sass'
    get '*.css' do
      filename = params[:splat].first
      sass filename.to_sym
    end
  end


  use CoffeeHandler
  use SassHandler

  ### Routes ###
  get '/' do
    @pages = hash_pages
    if settings.production?
      cache slim :index
    else
      slim :index
    end
  end

  # Generate robots.txt:
  get '/robots.txt' do
    "Sitemap: #{uri}/sitemap.xml"
  end

  # Generate atom feed:
  get '/atom.xml' do
    feed = TinyAtom::Feed.new(uri, SiteName, uri + '/atom.xml')
    n = 0
    a = hash_pages.flatten(2).select { |e| e.is_a? Hash }
    a = a.sort_by { |e| e['date'] }.reverse[0..15]
    a.each do |e|
      feed.add_entry(
        n += 1,
        e['title'],
        e['date'],
        uri + '/' + e['filepath'],
        :summary => e['desc'],
        #:content => e['body']
      )
    end
    feed = feed.make(:indent => 2)
    cache feed if settings.production?
    feed
  end

  # Generate sitemap:
  get '/sitemap.xml' do
    hostname = if request.port == 80 or request.port == 443
                 request.host
               else
                 request.host_with_port
               end
    map = XmlSitemap::Map.new(hostname, :root => false) do |m|
      # Manually add static urls to the sitemap:
      # [ "http://example.org/about", "http://example.org/news" ].each { |e| m.add e }
      hash_pages.each_pair do |k, v|
        if k == 'root'
          # Top-level pages; just need the files' basenames.
          v.each { |e| m.add e['title'] }
        else
          v.each { |e| m.add k + '/' + e['title'] }
        end
      end
    end
    content_type 'application/xml', :charset => 'utf-8'
    map.render_to '.cache/sitemap.xml' if settings.production?
    map.render
  end

  # Print view:
  get '/*/print' do
    filepath = PagesFolder + '/' + params[:splat].first
    relative_filepath = File.basename(PagesFolder) + '/' + params[:splat].first
    begin
      @meta = readmeta(filepath + '.textile')
      body = textile((@meta['body'] || relative_filepath.to_sym), :layout => :print_layout)
    rescue Errno::ENOENT
      begin
        @meta = readmeta(filepath + '.md')
        body = markdown((@meta['body'] || relative_filepath.to_sym), :layout => :print_layout)
      rescue Errno::ENOENT
      end
    end
    if body and settings.production?
      cache body
    elsif body
      body
    else
      raise Sinatra::NotFound
    end
  end

  get '/*' do
    @print_url = params[:splat].first + '/print'
    filepath = PagesFolder + '/' + params[:splat].first
    relative_filepath = File.basename(PagesFolder) + '/' + params[:splat].first
    begin
      @meta = readmeta(filepath + '.textile')
      body = textile @meta['body'] || relative_filepath.to_sym
    rescue Errno::ENOENT
      begin
        @meta = readmeta(filepath + '.md')
        body = markdown @meta['body'] || relative_filepath.to_sym
      rescue Errno::ENOENT
      end
    end
    if body and settings.production?
      cache body
    elsif body
      body
    else
      raise Sinatra::NotFound
    end
  end

  not_found do
    @pages = hash_pages
    if settings.production?
      redirect '/'
    else
      @error = 'Page not found.'
      slim :index
    end
  end

end
