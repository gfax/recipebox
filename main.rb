require 'sinatra'
require 'coffee-script'
require 'fileutils'
require 'redcloth'
require 'sass'
require 'slim'
require 'xml-sitemap'


### Configuration ###
class RecipeBox < Sinatra::Base

  SiteName = '#gfax'
  SiteTitle = 'gfax'
  PagesFolder = Dir.pwd + '/views/recipes/'
  ViewsFolder = Dir.pwd + '/views'
 
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

  def readline(file=nil)
    # Read unix timestamp from first line of file to get post date.
    if file
      file = PagesFolder + '/' + file
      line = File.open(file, &:readline).split[1].to_i
      return nil if line.zero?
      return Time.at(line).to_s
    end
    return nil
  end

  def hash_pages(folder=PagesFolder+'*/')
    # List used for recipe categories.
    a = Dir[folder].map { |f| File.basename(f) }
    # Create a hash to sort recipes in.
    h = {}
    # Start with recipes in each sub-directories.
    a.each do |e| 
      h[e] = Dir[PagesFolder + e + '/*'].select { |f| not File.directory? f }
      h[e].map! { |f| File.basename(f).chomp(File.extname(f)) }.sort!
    end
    # Category for recipes not in subfolders:
    h['misc'] = Dir[PagesFolder + '*'].select { |f| not File.directory? f }
    h['misc'].map! { |f| File.basename(f).chomp(File.extname(f)) }.sort!
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
      # Add subdomains.
      Dir[PagesFolder + "*.*"].each do |f|
        if File.basename(f) =~ /\.(md|textile)/
          # Don't add the index page since '/' is already added by default.
          next if File.basename(f) =~ /^index.(md|textile)/
          # Add the hostname + base filename to sitemap's urls.
          # This assumes a flat file structure and no pages in subdirectories.
          m.add File.basename(f).chomp(File.extname(f))
        end
      end
    end
    content_type 'application/xml', :charset => 'utf-8'
    map.render_to '.cache/sitemap.xml' if settings.production?
    map.render
  end

  get '/*' do
    begin
      @date = readline params[:splat].first + '.textile'
      item = textile "recipes/#{params[:splat].first}".to_sym
    rescue Errno::ENOENT
      begin
        @date = readline params[:splat].first + '.md'
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
    if settings.production?
      cache slim :index
    else
      #slim :index
      "not found"
    end
  end

end
