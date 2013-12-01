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
  PublicFolder = File.dirname(__FILE__) + '/public'
  ViewsFolder = File.dirname(__FILE__) + '/views'
  
  #set :environment, :production
  set :markdown,
    :layout_engine => :slim,
    :layout => :layout
  set :textile,
    :layout_engine => :slim,
    :layout => :layout
  set :public_folder, PublicFolder
  set :views_folder, ViewsFolder

  ### Caching ###
  def cache(text)
    # requests to / should be cached as index.html 
    uri = request.path_info == "/" ? 'index' : request.path_info
    # Don't cache pages with query strings. 
    unless uri =~ /\?/
      uri << '.html'
      # put all cached files in a subdirectory called '.cache'
      path = File.join(File.dirname(__FILE__), '.cache', uri)
      # Create the directory if it doesn't exist
      FileUtils.mkdir_p(File.dirname(path))
      # Write the text passed to the path
      File.open(path, 'w') { |f| f.write( text ) } unless File.exists?(path)
    end
    return text
  end

  def readline(file=nil)
    # Read unix timestamp from file.
    if file
      file = ViewsFolder + '/' + file
      line = File.open(file, &:readline).split[1].to_i
      return nil if line.zero?
      return Time.at(line).to_s
    end
    return nil
  end

  def hash_pages(folder=ViewsFolder+'/recipes/*/')
    # List used for recipe categories.
    a = Dir[folder].map { |f| File.basename(f) }
    a.reject!{ |e| e == 'sass' or e == 'coffeescript'}
    # Create a hash to sort recipes in.
    h = {}
    # Start with recipes in each sub-directories.
    a.each do |e| 
      h[e] = Dir[ViewsFolder + '/recipes/' + e + '/*'].select { |f| not File.directory? f }
      h[e].map! { |f| File.basename(f).chomp(File.extname(f)) }.sort!
    end
    # Category for recipes not in subfolders:
    h['misc'] = Dir[ViewsFolder + '/recipes/*'].select { |f| not File.directory? f }
    h['misc'].map! { |f| File.basename(f).chomp(File.extname(f)) }.sort!
    return h
  end

  class CoffeeHandler < Sinatra::Base
    set :views, ViewsFolder + '/coffeescript'
    get '*.js' do
      filename = params[:splat].first
      coffee filename.to_sym
    end
  end


  class SassHandler < Sinatra::Base
    set :views, ViewsFolder + '/sass'
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
      Dir[ViewsFolder + "/recipes/*.*"].each do |f|
        if File.basename(f) =~ /\.(md|textile)/
          # Don't add the index page since '/' is already added by default.
          next if File.basename(f) =~ /^index.(md|textile)/
          # Add the hostname + base filename to sitemap's urls.
          # This assumes a flat file structure and no pages in subdirectories.
          m.add File.basename(f).chomp(File.extname(f))
        end
      end
    end
    if settings.production?
      map.render_to 'public/sitemap.xml'
      redirect '/sitemap.xml'
    else
      content_type 'application/xml', :charset => 'utf-8'
      map.render
    end
  end

  get '/:item' do
    begin
      @date = readline 'recipes/' + params[:item] + '.textile'
      item = textile(('recipes/' + params[:item]).to_sym)
    rescue Errno::ENOENT
      begin
        @date = readline 'recipes/' + params[:item] + '.md'
        item = markdown(('recipes/' + params[:item]).to_sym)
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
      redirect '/'
    end
  end

  not_found do
    if settings.production?
      cache slim :index
    else
      slim :index
    end
  end

end
