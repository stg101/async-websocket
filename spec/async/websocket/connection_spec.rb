# Copyright, 2012, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'async/websocket'
require 'async/websocket/client'

require 'rack/test'
require 'falcon/server'
require 'falcon/adapters/rack'
require 'async/http/url_endpoint'

RSpec.describe Async::WebSocket::Connection, timeout: nil do
	include_context Async::RSpec::Reactor
	
	let(:server_address) {Async::HTTP::URLEndpoint.parse("http://localhost:9000")}
	let(:app) {Rack::Builder.parse_file(File.expand_path('../connection_spec.ru', __FILE__)).first}
	let(:server) {Falcon::Server.new(Falcon::Server.middleware(app, verbose: true), server_address)}

	it "should connect to the websocket server" do
		server_task = reactor.async do
			server.run
		end
		
		events = []
		
		Async::WebSocket::Client.open(server_address) do |connection|
			while event = connection.next_message
				expect(event).to include("line")
				
				events << event
			end
			
			connection.close # optional
		end
		
		expect(events.size).to be > 0
		
		server_task.stop
	end

	it "should negotiate protocol" do
		server_task = reactor.async do
			server.run
		end
		
		Async::WebSocket::Client.open(server_address, protocols: ['ws']) do |connection|
			expect(connection.protocol).to be == 'ws'
		end
		
		server_task.stop
	end
end
