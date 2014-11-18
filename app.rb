require 'rubygems'
require 'sinatra'
require 'rest_client'
require 'base64'
require 'securerandom'
require 'json'

configure do
  enable :sessions
end
set :session_secret, 'IMASECRETYAY'

# Pull API keys & creditor from the environment
CREDITOR_ID = ENV['CREDITOR_ID']
API_KEY_ID = ENV['API_KEY_ID']
API_KEY_SECRET = ENV['API_KEY_SECRET']

API_URL = "https://api-staging.gocardless.com"
HEADERS = {
  'GoCardless-Version' => '2014-11-03',
  'Content-Type' => 'application/json'
}

# Initialize the API client
API = RestClient::Resource.new(API_URL,
                               user: API_KEY_ID,
                               password: API_KEY_SECRET,
                               headers: HEADERS)

# Before every request, make sure visitors have been assigned a session ID.
before do
  session[:token] ||= SecureRandom.uuid
end

# Customer Vists the DVLA
get '/' do
  erb :index
end

# DVLA kicks off a redirection flow
post '/purchase' do
  package = params[:package]
  uri = URI.parse(request.env["REQUEST_URI"])
  success_url = "#{uri.scheme}://#{uri.host}/payment_complete?package=#{package}"

  payload = {
    redirect_flows: {
      description: "#{package.capitalize} License - £#{rand(1..5)*50}",
      session_token: session[:token],
      success_redirect_url: success_url,
      links: {
        creditor: CREDITOR_ID
      }
    }
  }

  response = API['/redirect_flows'].post payload.to_json
  redirect JSON.parse(response)["redirect_flows"]["redirect_url"]
end

# Customer returns from GC flow pages
get '/payment_complete' do
  redirect_flow_id = params[:redirect_flow_id]

  payload = {
    data: {
      session_token: session[:token]
    }
  }
  API["/redirect_flows/#{redirect_flow_id}/actions/complete"].post payload.to_json
  redirect "/thankyou?package=#{params[:package]}"
end

get '/thankyou' do
  @package = params[:package]
  erb :thankyou
end
