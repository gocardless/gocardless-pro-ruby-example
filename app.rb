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
  api_secret: Prius.get(:api_key_secret),
  environment: :sandbox
)

PACKAGE_PRICES = {
  "bronze" => { "GBP" => 100, "EUR" => 130 },
  "silver" => { "GBP" => 500, "EUR" => 700 },
  "gold" => { "GBP" => 1000, "EUR" => 1300 }
}

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
    description: "#{package.capitalize} License",
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
  price = PACKAGE_PRICES.fetch(package)

  # Complete the redirect flow
  puts session[:token]
  puts redirect_flow_id

  completed_redirect_flow = API_CLIENT.redirect_flows.
    complete(redirect_flow_id, session_token: session[:token])

  mandate = API_CLIENT.mandates.get(completed_redirect_flow.links.mandate)

  # Create the subscription
  currency = case mandate.scheme
             when "bacs" then "GBP"
             when "sepa_core" then "EUR"
             end

  subscription = API_CLIENT.subscriptions.create(
    amount: price[currency] * 100, # Price in pence/cents
    currency: currency,
    name: "Monthly Rental (#{package.capitalize} Package)",
    interval_unit: "monthly",
    day_of_month:  "1",
    metadata: {
      order_no: SecureRandom.uuid # Could be anything
    },
    links: {
      mandate: mandate.id
    }
  )

  redirect "/thankyou?package=#{package}&subscription_id=#{subscription.id}"
end

get '/thankyou' do
  @package = params[:package]
  subscription = API_CLIENT.subscriptions.get(params[:subscription_id])
  currency = subscription.currency

  currency_symbol = case currency
                    when "GBP" then "£"
                    when "EUR" then "€"
                    end
  @price = "#{currency_symbol}#{"%.2f" % PACKAGE_PRICES[@package][currency]}"
  @first_payment_date = subscription.upcoming_payments.first[:charge_date]
  erb :thankyou
end
