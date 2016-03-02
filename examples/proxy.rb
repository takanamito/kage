#!/usr/bin/env ruby
require 'kage'

def compare(production_res, sandbox_res, url)
  return if url.include?('/assets/')

  production_parser = Http::Parser.new
  production_parser << production_res
  sandbox_parser = Http::Parser.new
  sandbox_parser << sandbox_res

  p "Response Diff #{production_parser.status_code}, #{sandbox_parser.status_code}, #{url}" if production_parser.status_code != sandbox_parser.status_code && production_parser.status_code != 302
end

Kage::ProxyServer.start do |server|
  server.port = 8090
  server.host = '0.0.0.0'
  server.debug = false

  # backends can share the same host/port
  server.add_master_backend(:production, 'localhost', 80)
  server.add_backend(:sandbox, 'localhost', 80)

  server.client_timeout = 15
  server.backend_timeout = 10

  # Dispatch all GET requests to multiple backends, otherwise only :production
  server.on_select_backends do |request, headers|
    if request[:method] == 'GET'
      [:production, :sandbox]
    else
      [:production]
    end
  end

  # Add optional headers
  server.on_munge_headers do |backend, headers|
    headers['X-Kage-Session'] = self.session_id
    headers['X-Kage-Sandbox'] = 1 if backend == :sandbox
  end

  # This callback is only fired when there are multiple backends to respond
  server.on_backends_finished do |backends, requests, responses|
    compare(responses[:production][:data], responses[:sandbox][:data], requests.first[:url])
  end
end
