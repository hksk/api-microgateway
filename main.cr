require "option_parser"
require "yaml"
require "json"


arg_port=9999
arg_bind="0.0.0.0"
arg_conf="./conf"
arg_host="localhost"

OptionParser.parse! do |parser|
  parser.banner = "Usage: [arguments]"
  parser.on("-p PORT", "--port=PORT", "port") { |port| arg_port = port }
  parser.on("-b BIND", "--bind=BIND", "bind address") { |bind| arg_bind = bind }
  parser.on("-c CONF", "--config_dir=CONF", "directory config") { |conf| arg_conf = conf }
  parser.on("-h HOST", "--host=HOST", "directory config") { |host| arg_host = host }
  parser.on("-h", "--help", "Show this help") { puts parser }
end

puts "Configurations"
puts "port: #{arg_port}"
puts "bind address: #{arg_bind}"
puts "directory conf: #{arg_conf}"
puts "route to host (lb): #{arg_host}"

request_table = Hash(String, Array(YAML::Any)).new

Dir.glob("#{arg_conf}/*") do |file|
	definition = YAML.parse(File.read("#{file}"))
	definition["endpoints"].each do |endpoint|
		uri = endpoint["endpoint"].to_s
		backend = endpoint["backend"].to_a
		request_table[uri] = backend
	end
end

pp request_table

########################################### filters

def filter_return(method,url)
	response = HTTP::Client.exec method, url
	return response.body.to_s
end
def filter_noreturn(method,url)
	response = HTTP::Client.exec method, url
	return ""
end
def filter_parallel(method,url)
	response = HTTP::Client.exec method, url
	return "response"
end






def filter_invoke(r_method, r_uri, r_filter)
	case r_filter
	when "parallel"
		return filter_parallel(r_method, r_uri)
	when "noreturn"
		return filter_noreturn(r_method, r_uri)
	else
		return filter_return(r_method, r_uri)
	end
end



##################################################

require "http/server"
server = HTTP::Server.new(arg_bind, arg_port.to_i) do |context|
	key="#{context.request.method}:#{context.request.resource}"
	pp key
	prepends = ""
	response = ""
	value = Hash(JSON::Any,JSON::Any).new
	responseJson = JSON.parse("[]")
	pp "response: "
	chain = request_table[key] rescue 404
	if chain == 404
		context.response.status_code = 404
		context.response.print "Meditation Error! not found"
	else
		request_table[key].each do | reqs |
			definition = reqs.to_s.split(":")
			r_method = definition[0]
			r_uri = definition[1]
			r_filter = definition[2] rescue "return"
#			response += filter_invoke(r_method, arg_host+r_uri, r_filter)
			puts r_method, arg_host+r_uri, r_filter
#			value = JSON.parse( "["+filter_invoke(r_method, arg_host+r_uri, r_filter)+"]" )
#			puts value[0]
			prepends = JSON.parse( filter_invoke(r_method, arg_host+r_uri, r_filter) )
#			puts value["ws.user"]
#			context.response.print "method: #{r_method}, uri: #{r_uri}, concat: #{r_concat}"
			prepends.each do |key, xvalue|
				value[key] = xvalue
			end
		end
#		puts value
		#puts JSON.parse(value)
		context.response.print value
#		context.response.print "ALL OK!"
	end
end

puts "Listening http server"
server.listen