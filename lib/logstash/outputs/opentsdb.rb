# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"
require "socket"

# This output allows you to pull metrics from your logs and ship them to
# opentsdb. Opentsdb is an open source tool for storing and graphing metrics.
#
class LogStash::Outputs::Opentsdb < LogStash::Outputs::Base
  config_name "opentsdb"

  # The address of the opentsdb server.
  config :host, :validate => :string, :default => "localhost"

  # The port to connect on your graphite server.
  config :port, :validate => :number, :default => 4242
  
  # The metric name
  config :metric, :validate => :string, :required => true  

  # The timestamp long number
  config :timestamp, :validate => :number, :required => true
  
  # The value
  config :value, :validate => :number, :required => true
  
  # The tags, k1=v1,k2=v2
  config :tags, :validate => :string, :default => "k=v"

  def register
    connect
  end # def register

  def connect
    # TODO(sissel): Test error cases. Catch exceptions. Find fortune and glory.
    begin
      @socket = TCPSocket.new(@host, @port)
    rescue Errno::ECONNREFUSED => e
      @logger.warn("Connection refused to opentsdb server, sleeping...",
                   :host => @host, :port => @port)
      sleep(2)
      retry
    end
  end # def connect

  public
  def receive(event)
    # Opentsdb message format: put metric timestamp value tagname=tagvalue tag2=value2\n
    # Catch exceptions like ECONNRESET and friends, reconnect on failure.
    begin
      # The first part of the message
      message = ['put',
                 event.sprintf(metric),
                 event.sprintf(timestamp),
                 event.sprintf(value),
                 event.sprintf(tags).split(',').join(' '),
      ].join(' ')
    end
    
    begin
      @socket.puts(message)
    rescue Errno::EPIPE, Errno::ECONNRESET => e
      @logger.warn("Connection to opentsdb server died",
                   :exception => e, :host => @host, :port => @port)
      sleep(2)
      connect
    end
  end # def receive
end # class LogStash::Outputs::Opentsdb
