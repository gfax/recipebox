# coding: UTF-8
class RecipeBox < Sinatra::Base

  ### Configuration ###
  SiteName = '#gfax'
  SiteTitle = 'gfax'
  PagesFolder = File.dirname(__FILE__) + '/views/recipes/'
  ViewsFolder = File.dirname(__FILE__) + '/views'
 
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
    uri = request.path_info == "/" ? 'index' : request.path_info
    # Don't cache pages with query strings. 
    unless uri =~ /\?/
      uri << '.html'
      # Put all cached files in a subdirectory called '.cache'.
      path = File.join(File.dirname(__FILE__), '.cache', uri)
      # Create the directory if it doesn't exist.
      FileUtils.mkdir_p(File.dirname(path))
      # Write the text passed to the path.
      File.open(path, 'w') { |f| f.write( text ) } unless File.exists?(path)
    end
    return text
  end

  def readtime(file=nil)
    # Read unix timestamp from first line of file to get post date.
    if file
      file = PagesFolder + '/' + file
      timestamp = File.open(file, &:readline).split[1].to_i
      return nil if timestamp.zero?
      return Time.at(timestamp).to_s
    end
    return nil
  end

  def readmeta(file=nil)
    meta = {}
    if file
      lines = File.open(file)
      meta[:name] = File.basename(file, File.extname(file))
      meta[:date] = lines.gets.split[1].to_i
      meta[:date] = meta[:date].zero? ? nil : Time.at(meta[:date]).to_s
      meta[:desc] = lines.gets.split[0..-1]
      meta[:desc] = meta[:desc].include?('<!--') ? meta[:desc][1..-2].join(' ').chomp : nil
    end
    return meta
  end

  def hash_pages(folder=PagesFolder)
    # Array of recipe categories.
    a = Dir.glob(folder + '**/').map { |f| f.sub(folder, '').chop }
    # Remove root directory. We'll manually add this on at the end.
    a.shift
    # Create a hash to sort recipes in.
    h = {}
    # Start with recipes in each sub-directories.
    a.each do |e| 
      h[e] = Dir[folder + e + '/*'].select { |f| not File.directory? f }.sort
      # Collect html comments into sub-hashes.
      h[e].map! { |filepath| readmeta(filepath) }
    end
    # Category for pages in the root directory:
    h['misc'] = Dir[folder + '*'].select { |f| not File.directory? f }.sort
    h['misc'].map! { |filepath| readmeta(filepath) }
    return h
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
    @recipes = hash_pages
    if settings.production?
      cache slim :index
    else
      slim :index
    end
  end

  ### Generate Sitemap ###
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
        if k == 'misc'
          # Top-level pages; just need the files' basenames.
          v.each { |e| m.add e }
        else
          v.each { |e| m.add k + '/' + e }
        end
      end
    end
    content_type 'application/xml', :charset => 'utf-8'
    map.render_to '.cache/sitemap.xml' if settings.production?
    map.render
  end

  get '/*' do
    begin
      @date = readtime params[:splat].first + '.textile'
      item = textile "recipes/#{params[:splat].first}".to_sym
    rescue Errno::ENOENT
      begin
        @date = readtime params[:splat].first + '.md'
        item = markdown "recipes/#{params[:splat].first}".to_sym
      rescue Errno::ENOENT
      end
    end
    if item
      if settings.production?
        cache item
      else
        item
      end
    else
      raise Sinatra::NotFound
    end
  end

  not_found do
    @recipes = hash_pages
    if settings.production?
      redirect '/'
    else
      @error = 'Page not found.'
      slim :index
    end
  end

end
