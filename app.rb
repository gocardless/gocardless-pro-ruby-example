require 'rubygems'
require 'sinatra'
require 'rest_client'
require 'securerandom'
require 'json'

# Enable sessions
enable :sessions
set :session_secret, 'im_a_secret_yay!'

# Pull API keys & creditor from the environment
CREDITOR_ID = Prius.get(:creditor_id)
API_KEY_ID = Prius.get(:api_key_id)
API_KEY_SECRET = Prius.get(:api_key_secret)
API_ENDPOINT = Prius.get(:api_endpoint)

HEADERS = {
  'GoCardless-Version' => Prius.get(:api_version),
  'Content-Type' => 'application/json'
}

# Initialize the API client
API = RestClient::Resource.new(API_ENDPOINT,
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
      scheme: 'bacs',
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
