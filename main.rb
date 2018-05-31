require 'sinatra'
require 'sinatra/contrib/all'
require "http"
require "sinatra/reloader"
require 'yaml'
require "pp"
require 'ostruct'
require 'json'


set :bind, '0.0.0.0'
set :port, 9999

$server = "http://api.geointranet"
# read conf and create table route
ymlfiles = Dir["conf/*.yml"]
endpoints = {}
ymlfiles.each do |file| 
	newConfig = YAML.load_file(file)
	endpoints = endpoints.merge(newConfig){ |key,oldval,newval| oldval | newval }
end
rawEndpoints = endpoints["endpoints"]

MicroGateway = OpenStruct.new
MicroGateway.endpoint = []
MicroGateway.endpoint_list = []
rawEndpoints.each do |endpoint|
	endp = OpenStruct.new
	edata = endpoint["endpoint"].split(":")
	endp.http_method = edata[0]
	endp.uri = edata[1]
	endp.backend = []
	endpoint["backend"].each do |bke|
		backend_object = OpenStruct.new
		bdata = bke.split(":")
		backend_object.http_method = bdata[0]
		backend_object.uri = bdata[1]
		backend_object.filter = bdata[2].nil? ? "return" : bdata[2]
		endp.backend  << backend_object
	end
	MicroGateway.endpoint_list << endp.uri
	MicroGateway.endpoint << endp
end
#puts MicroGateway
#
###

def d(message)
	pp "#{DateTime.now} #{message}"
end

def requests_chain(backend_list,params)
	params_chain = params
	response = {}
	params_prepared = params
	chain_id = SecureRandom.hex
	d "CHAIN============================================="
	backend_list.each do |backend|
		smethod = backend.http_method.downcase
		suri = backend.uri.downcase
		if smethod == "get"
			send_data = {:params => params_prepared}
		else
			send_data = {:json => params_prepared}	
		end
		response = HTTP.send(smethod,$server+suri, send_data )
		responseReq = JSON.parse(response.to_s,object_class: Hash) rescue {}
		params_prepared = params_prepared.merge(responseReq)
		d " "
		d "    id: #{chain_id}"
		d "    URI: #{suri} [#{smethod}]"
		d "    to send: #{params_prepared.to_s}"
		d "    received: #{responseReq.to_s}"
	end
	d "=================================================="
	return response
end


####
route :get, :post, :delete, :put, '/*' do
  # "GET" or "POST"
  uri = request.path_info
  if uri[-1] == "/"
  	uri = uri[0..-2]
  end
  tError = true
  tEndpoint = nil
  indexEndpoint = MicroGateway.endpoint_list.index(uri)
  if !indexEndpoint.nil?
  	tError = false
  	tEndpoint = MicroGateway.endpoint[indexEndpoint]
 # 	p "found! "
  end

  if !tEndpoint.nil?
  	if tEndpoint.http_method != request.env["REQUEST_METHOD"]
  		tError = true
  	end
  end

  if tError
  	status 400
  	return "ERROR -  Meditation Machine - BAD Req"
  else
  	d "Start Request: #{uri} [#{tEndpoint.http_method}]"
  	response = requests_chain(tEndpoint.backend,params)
  	return response.to_s
  end
end