#!/usr/bin/env ruby

require 'async'
require 'async/semaphore'
require 'async/clock'
require 'async/io/stream'
require 'async/http/url_endpoint'
require_relative '../../lib/async/websocket/client'

require 'samovar'

require 'tty/progressbar'

class Command < Samovar::Command
	options do
		option "-c/--count <integer>", "The total number of connections to make.", default: 1000, type: Integer
		option "--bind <address>", "The local address to bind to before making a connection."
		option "--connect <string>", "The remote server to connect to.", default: "ws://localhost:8080"
		
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

		Async do |task|
			task.logger.info!
			
			task.async do
				while connection = connections.dequeue
					task.async(*connection) do |subtask, socket, client|
						while message = client.next_message
							pp message
						end
					ensure
						socket.close
					end
				end
			end
			
			count.times do |i|
				socket = endpoint.connect
				client = Async::WebSocket::Client.new(socket, @options[:connect])
					
				connections.enqueue([socket, client])
				progress.advance(1)
			end
			
			connections.enqueue(nil)
		end
	end
end

Command.call