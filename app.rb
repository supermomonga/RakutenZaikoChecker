# coding: utf-8
require 'rubygems'
require 'data_mapper'
require 'thor'
require 'net/http'
require 'erb'

DataMapper.setup(:default, "sqlite://#{ File.dirname(File.expand_path( __FILE__ )) }/items.db")


class Item
  include DataMapper::Resource
  property :id         , Serial
  property :name       , String
  property :url        , String
  property :available  , Boolean
  property :created_at , DateTime
  property :updated_at , DateTime, default: true
end

class Status
  include DataMapper::Resource
  property :id         , Serial
  property :name       , String
  property :url        , String
  property :available  , Boolean
  property :created_at , DateTime
  property :updated_at , DateTime
end

DataMapper.auto_upgrade!

class Checker < Thor

  desc "list", "Show all url for checking"
  def list
    if Item.count == 0
      puts "There are no url."
    else
      puts "ID   | NAME | URL"
      puts "-----------------"
      Item.all.each do |item|
        puts ["%04d" % item.id, item.name, item.url].join " | "
      end
    end
  end

  desc "add [NAME] [URL]", "Add new url for checking"
  option :name, type: :string, aliases: '-n', desc: 'Name of item'
  option :url, type: :string, aliases: '-u', desc: 'URL of item page'
  def add(name, url)
    puts "Adding [#{ name }, #{ url }]..."
    item = Item.create name: name, url: url, created_at: Time.now, updated_at: Time.now
    if item.save
      puts "Done."
    else
      puts "Failed. Something seems wrong..."
    end
  end


end

Checker.start

# puts ERB::Util.url_encode ''
