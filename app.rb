# coding: utf-8
require 'rubygems'
require 'data_mapper'
require 'thor'
require 'net/http'
require 'uri'
require 'erb'
require 'terminal-table'

DataMapper.setup(:default, "sqlite://#{ File.dirname(File.expand_path( __FILE__ )) }/items.db")

class Item
  include DataMapper::Resource
  property :id         , Serial
  property :name       , String
  property :url        , String, unique: true
  property :available  , Boolean, default: true
  property :created_at , DateTime
  property :updated_at , DateTime
end

class Log
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
      puts 'There are no url.'
    else
      Terminal::Table.new headings: ['ID', 'NAME', 'URL', 'AVAILABLE', 'CREATED AT', 'UPDATED AT'] do |t|
        Item.all.each do |item|
          t << [item.id, item.name, item.url, item.available, item.created_at, item.updated_at]
        end
        puts t
      end
    end
  end

  desc 'add [NAME] [URL]', 'Add new url for checking'
  option :name, type: :string, aliases: '-n', desc: 'Name of item'
  option :url, type: :string, aliases: '-u', desc: 'URL of item page'
  def add name, url
    now = Time.now
    item = Item.create name: name, url: url, created_at: now, updated_at: now
    puts item.save ? 'Successfully added.' : 'Adding failed.'
  end

  desc 'remove [ID]', 'Remove url'
  option :id, type: :string, desc: 'ID of remove item'
  def remove id
    item = Item.get id
    puts ( item and item.destroy ) ? 'Successfully removed.' : 'Removing failed.'
  end

  desc 'check [ID]', 'Check stock and update log'
  option :id, type: :string, desc: 'ID of check item'
  def check id
    item = Item.get id
    if item
      res = URI.parse(item.url).tap do |uri|
        res = Net::HTTP.start(uri.host, uri.port) do |http|
          http.request(Net::HTTP::Get.new(uri.path))
        end
        break res
      end
      body = res.body.encode('UTF-8', 'EUC-JP')
      if body
        available = /<span class="soldout_msg">売り切れました<br>/ =~ body
        if available != item.available
          now = Time.now
          item.available = available
          item.updated_at = now
          puts item.save ? 'Item successfully saved.' : 'Item saving failed.'
          log = Log.create({
            name: item.name,
            url: item.url,
            available: item.available,
            created_at: now,
            updated_at: now
          })
          puts log.save ? 'Log successfully saved.' : 'Log saving failed.'
        end
      end
    end
  end
end

Checker.start

# puts ERB::Util.url_encode ''
