#require 'sinatra'
require 'bundler'

Bundler.require

require File.expand_path '../recipebox.rb', __FILE__

run RecipeBox
