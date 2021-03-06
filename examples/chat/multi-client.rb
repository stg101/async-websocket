#!/usr/bin/env ruby

require 'async'
require 'async/semaphore'
require 'async/clock'
require 'async/io/stream'
require 'async/http/url_endpoint'
require_relative '../../lib/async/websocket/client'

require 'samovar'
require 'ruby-prof'

require 'tty/progressbar'

GC.disable

class Command < Samovar::Command
	options do
		option "-c/--count <integer>", "The total number of connections to make.", default: 1000, type: Integer
		option "--bind <address>", "The local address to bind to before making a connection."
		option "--connect <string>", "The remote server to connect to.", default: "http://127.0.0.1:8080"
		
		option "-s/--semaphore <integer>", "The number of simultaneous connections to perform."
	end
	
	def local_address
		if bind = @options[:bind]
			Async::IO::Address.tcp(bind, 0)
		end
	end
	
	def call
		endpoint = Async::HTTP::URLEndpoint.parse(@options[:connect], local_address: self.local_address)
		count = @options[:count]
		
		connections = Async::Queue.new
		progress = TTY::ProgressBar.new(":rate connection/s [:bar] :current/:total (:eta/:elapsed)", total: count)
		
		# profile = RubyProf::Profile.new(merge_fibers: true)
		# profile.start
		
		Async do |task|
			task.logger.info!
			
			task.async do |subtask|
				while connection = connections.dequeue
					subtask.async(connection) do |subtask, connection|
						pp connection.next_message
						
						while message = connection.next_message
							pp message
						end
					ensure
						connection.close
					end
				end
				
				# subtask.children.each(&:stop)
			end
			
			client = Async::WebSocket::Client.new(endpoint)
			
			count.times do |i|
				connections.enqueue(client.get)
				progress.advance(1)
			end
			
			connections.enqueue(nil)
		end
	
	# ensure
	# 	result = profile.stop
	# 	printer = RubyProf::FlatPrinter.new(result)
	# 	printer.print(STDOUT, min_percent: 0.5)
	# 
	# 	printer = RubyProf::GraphPrinter.new(result)
	# 	printer.print(STDOUT, min_percent: 0.5)
	end
end

Command.call
