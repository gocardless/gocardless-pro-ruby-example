require 'rubygems'
require 'sinatra'
require 'securerandom'
require 'json'

require 'prius'
require 'gocardless'

# Enable sessions
enable :sessions
set :session_secret, 'im_a_secret_yay!'

# Load Environment Variables
Prius.load(:creditor_id)
Prius.load(:api_key_id)
Prius.load(:api_key_secret)
Prius.load(:api_endpoint)
Prius.load(:api_version)

# Put the environment variables in constants for easier access/reference
CREDITOR_ID = Prius.get(:creditor_id)
API_KEY_ID = Prius.get(:api_key_id)
API_KEY_SECRET = Prius.get(:api_key_secret)
API_ENDPOINT = Prius.get(:api_endpoint)

API_CLIENT = GoCardless::Client.new(
  api_key: Prius.get(:api_key_id),
  api_secret: Prius.get(:api_key_secret)
)

# Before every request, make sure visitors have been assigned a session ID.
before do
  session[:token] ||= SecureRandom.uuid
end

# Customer visits the site. Hi Customer!
get '/' do
  erb :index
end

# Customer purchases an item
post '/purchase' do
  package = params[:package]

  # Generate a success URL. This is where GC will send the customer after they've paid.
  uri = URI.parse(request.env["REQUEST_URI"])
  success_url = "#{uri.scheme}://#{uri.host}/payment_complete?package=#{package}"


  redirect_flow = API_CLIENT.redirect_flows.create(
    description: "#{package.capitalize} License - £#{rand(1..5)*50}",
    session_token: session[:token],
    success_redirect_url: success_url,
    scheme: params[:scheme],
    links: {
      creditor: CREDITOR_ID
    }
  )
  redirect redirect_flow.redirect_url
end

# Customer returns from GC's payment pages
get '/payment_complete' do
  package = params[:package]
  redirect_flow_id = params[:redirect_flow_id]

  API_CLIENT.redirect_flows.complete(rediirect_flow_id, session_token: session[:token])
  redirect "/thankyou?package=#{package}"
end

get '/thankyou' do
  @package = params[:package]
  erb :thankyou
end
