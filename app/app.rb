require 'sinatra'
require 'faraday'
require 'faraday_middleware'
require 'json'



set :port, 8080
set :static, true
set :public_folder, "static"
set :views, "views"

dash_api_key = ENV['DASHBOARD_API_KEY']
dash_org_id  = ENV['DASHBOARD_API_ORG_ID']
dash_shard_id = ENV['DASHBOARD_API_SHARD_ID']

get '/' do
    return 'all your base are belong to us'
end

get '/onboarding/' do
    erb :onboarding_form
end

post '/onboarding/' do

serial = params[:serial]
first_name = params[:first_name]
last_name = params[:last_name]
locale = params[:locale]
team = params[:team]

#Build the connection using faraday gem.
conn = Faraday.new(:url => "https://#{dash_shard_id}.meraki.com") do |faraday|
  faraday.request  :url_encoded             # form-encode POST params
  faraday.response :logger                  # log requests to STDOUT
  faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
end

# Add Device to Inventory
response = conn.post do |request|
  request.url "/api/v0/organizations/#{dash_org_id}/claim"
  request.headers['X-Cisco-Meraki-API-Key'] = "#{dash_api_key}"
  request.headers['Content-Type'] = 'application/json'
  request.body = "{\"serial\":\"#{serial}\"}"
#
# To do: get response and if status is something bad (like 400) stop there and tell user that the device is already claimed.
#
end


# Create Dashboard Teleworker Network
network_name = 'Teleworker - ' + "#{first_name}" + ' ' + "#{last_name}"


response = conn.post do |request|
  request.url "/api/v0/organizations/#{dash_org_id}/networks"
  request.headers['X-Cisco-Meraki-API-Key'] = "#{dash_api_key}"
  request.headers['Content-Type'] = 'application/json'
  request.body = "{\"name\":\"#{network_name}\", \"type\":\"appliance\", \"tags\":\"#{locale} #{team}\"}"
end

json_response = JSON.parse(response.body)
network_id = json_response['id']


# Bind Network to a Template. First figure out which template to bind to.

case locale
when "San_Francisco"
  template_id = 'N_566890603095264847'
when "Sydney"
  template_id = 'N_566890603095264849'
when "London"
  template_id = 'N_566890603095266301'
else
  template_id = 'N_566890603095264847' # Default to San Francisco
end


response = conn.post do |request|
  request.url "/api/v0/networks/#{network_id}/bind" 
  request.headers['X-Cisco-Meraki-API-Key'] = "#{dash_api_key}"
  request.headers['Content-Type'] = 'application/json'
  request.body = "{\"configTemplateId\":\"#{template_id}\", \"autoBind\":false}"
end



# Claim device into network
response = conn.post do |request|
  request.url "/api/v0/networks/#{network_id}/devices/claim"
  request.headers['X-Cisco-Meraki-API-Key'] = "#{dash_api_key}"
  request.headers['Content-Type'] = 'application/json'
  request.body = "{\"serial\":\"#{serial}\"}"
end


serial = params[:serial]
first_name = params[:first_name]
last_name = params[:last_name]
locale = params[:locale]
team = params[:team]

erb :index, :locals => {'first_name' => first_name, 'last_name' => last_name, 'team' => team, 'locale' => locale, 'serial' => serial}



end
