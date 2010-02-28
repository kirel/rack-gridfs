require 'timeout'
require 'mongo'
require 'mongo/gridfs'

module Rack
  
  class GridFSConnectionError < StandardError ; end
  
  class GridFS

    attr_reader :hostname, :port, :database, :prefix, :connection
    
    def initialize(app, options = {})
      options = {
        :hostname => 'localhost', 
        :port => Mongo::Connection::DEFAULT_PORT,
        :prefix => 'gridfs'
      }.merge(options)

      @app        = app
      @hostname   = options[:hostname]
      @port       = options[:port]
      @database   = options[:database]
      @prefix     = options[:prefix]
      @connection = nil

      connect!
    end

    def call(env)
      request = Rack::Request.new(env)
      if %w(GET HEAD).include?(request.request_method) && request.path_info =~ /^\/#{prefix}\/(.+)$/
        case request.request_method
        when "GET"
          gridfs_request($1)
        when "HEAD"
          gridfs_head_request($1)
        end
      else
        @app.call(env)
      end
    end

    def not_found
      [404, {'Content-Type' => 'text/plain'}, ['File not found.']]
    end

    def gridfs_request(key)
      if ::GridFS::GridStore.exist?(connection, key)
        body = ::GridFS::GridStore.new(connection, key, 'r')
        [200, {'Content-Type' => body.content_type}, body]
      else
        not_found
      end
    end

    def gridfs_head_request(key)
      if ::GridFS::GridStore.exist?(connection, key)
        ::GridFS::GridStore.open(connection, key, 'r') do |f|
          [200, {'Content-Type' => f.content_type}, []]
        end
      else
        not_found
      end
    end
    
    private
    
    def connect!
      Timeout::timeout(5) do
        @connection = Mongo::Connection.new(hostname).db(database)
      end
    rescue Exception => e
      raise Rack::GridFSConnectionError, "Unable to connect to the MongoDB server (#{e.to_s})"
    end
    
  end
    
end
