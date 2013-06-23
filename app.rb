#!/usr/bin/env ruby
# coding: utf-8
require 'rubygems'
require 'data_mapper'
require 'thor'
require 'open-uri'
require 'erb'
require 'terminal-table'
require 'mandrill'
require 'nkf'

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

  desc "logs", "Show all log of stock status"
  option :id, type: :string, desc: 'ID of item'
  def logs
    if Log.count == 0
      puts 'There are no log.'
    else
      Terminal::Table.new headings: ['DATETIME', 'NAME', 'URL', 'AVAILABLE'] do |t|
        if options.id?
          item = Item.get(options.id)
          t.title = "Stock log of #{ item.name }"
        end
        logs = item ? Log.all(url: item.url) : Log.all
        logs.each do |log|
          t << [log.created_at.strftime("%Y-%m-%d %H:%M:%S"), log.name, log.url, log.available ? 'in stock' : 'out of stock']
        end
        t.align_column 0, :right
        puts t
      end
    end
  end

  desc "list", "Show all url for checking"
  def list
    if Item.count == 0
      puts 'There are no url.'
    else
      Terminal::Table.new headings: ['ID', 'NAME', 'URL', 'AVAILABLE', 'CREATED AT', 'UPDATED AT'] do |t|
        Item.all.each do |item|
          t << [item.id, item.name, item.url, item.available ? 'in stock' : 'out of stock', item.created_at.strftime("%Y-%m-%d %H:%M:%S"), item.updated_at.strftime("%Y-%m-%d %H:%M:%S")]
        end
        t.align_column 0, :right
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
  option :email, type: :string, aliases: '-m', desc: 'Email to send notice if item switched to unavailable.'
  option :apikey, type: :string, aliases: '-a', desc: 'MANDRILL api-key to send email notification'
  def check id
    puts "Checking item(id:#{ id })"
    item = Item.get id
    if item
      begin
        res = open(item.url)
      rescue
        puts 'URL parse failed.'
      end
      if res
        begin
          body = res.read.encode('UTF-8')
        rescue
          puts "Can't convert encoding."
        end
        if body
          puts "Checking stock"
          available = body =~ /<span class="soldout_msg">売り切れました<br>/ ? false : true
          puts "Stock is #{ available ? 'in' : 'out' }"
          if available != item.available
            now = Time.now
            item.available = available
            item.updated_at = now
            puts item.save ? 'Item successfully saved.' : 'Item saving failed.'
            log = Log.create(
              name: item.name,
              url: item.url,
              available: item.available,
              created_at: now,
              updated_at: now
            )
            puts log.save ? 'Log successfully saved.' : 'Log saving failed.'
            if options[:email] and options[:apikey] and available == false
              m = Mandrill::API.new options[:apikey]
              message = {
                subject: "商品「#{ item.name }」が売り切れました",
                from_name: '楽天在庫チェッカー',
                text: "URL:#{ item.url }\nDATE:#{ now }",
                to: [ { email: options[:email] } ],
                  from_email: 'extends.hk+noreply@gmail.com'
              }
              sending = m.messages.send message
              puts sending
            end
          end
        end
      end
    end
  end

  desc 'checkall', 'Check stock and update log with all items.'
  option :email, type: :string, aliases: '-m', desc: 'Email to send notice if item switched to unavailable.'
  option :apikey, type: :string, aliases: '-a', desc: 'MANDRILL api-key to send email notification'
  def checkall
    Item.all.each do |item|
      check item.id
      sleep 1
    end
  end
end


Checker.start

# puts ERB::Util.url_encode ''
