require 'rubygems'
require 'sinatra'
require 'securerandom'
require 'json'

require 'prius'
require 'gocardless'
require 'i18n'
require 'i18n/backend/fallbacks'
require 'rack'
require 'rack/contrib'

require_relative "lib/environment"

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

PACKAGE_PRICES = {
  "bronze" => { "GBP" => 100, "EUR" => 130 },
  "silver" => { "GBP" => 500, "EUR" => 700 },
  "gold" => { "GBP" => 1000, "EUR" => 1300 }
}

# Internationalisation by browser preference
use Rack::Locale

# Settings
set :session_secret, 'im_a_secret_yay!'
set :api_client, GoCardless::Client.new(
  api_key: Prius.get(:api_key_id),
  api_secret: Prius.get(:api_key_secret),
  environment: :sandbox
)

# Configuration
configure do
  I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
  I18n.load_path = Dir[File.join(settings.root, 'locales', '*.yml')]
  I18n.backend.load_translations
  I18n.config.enforce_available_locales = false
  I18n.default_locale = :en
end

# Enable sessions and before every request, make sure visitors have been assigned a
# session ID.
enable :sessions
before { session[:token] ||= SecureRandom.uuid }

# Customer visits the site. Hi Customer!
get '/' do
  @prices = {}

  PACKAGE_PRICES.each do |package, pricing_hash|
    @prices[package.to_sym] = case I18n.locale
                              when :fr then "€#{pricing_hash["EUR"]}"
                              else "£#{pricing_hash["GBP"]}"
                              end
  end

  erb :index
end

# Customer purchases an item
post '/purchase' do
  package = params[:package]

  # Generate a success URL. This is where GC will send the customer after they've paid.
  uri = URI.parse(request.env["REQUEST_URI"])
  success_url = "#{uri.scheme}://#{uri.host}#{":#{uri.port}" unless [80, 443].include?(uri.port)}/payment_complete?package=#{package}"

  redirect_flow = settings.api_client.redirect_flows.create(
    description: I18n.t(:package_description, package: package.capitalize),
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

  completed_redirect_flow = settings.api_client.redirect_flows.
    complete(redirect_flow_id, session_token: session[:token])

  mandate = settings.api_client.mandates.get(completed_redirect_flow.links.mandate)

  # Create the subscription
  currency = case mandate.scheme
             when "bacs" then "GBP"
             when "sepa_core" then "EUR"
             end

  subscription = settings.api_client.subscriptions.create(
    amount: price[currency] * 100, # Price in pence/cents
    currency: currency,
    name: I18n.t(:package_description, package: package.capitalize),
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
  package = params[:package]
  subscription = settings.api_client.subscriptions.get(params[:subscription_id])
  currency = subscription.currency

  currency_symbol = case currency
                    when "GBP" then "£"
                    when "EUR" then "€"
                    end
  @price = "#{currency_symbol}#{"%.2f" % PACKAGE_PRICES[package][currency]}"
  @first_payment_date = subscription.upcoming_payments.first[:charge_date]
  @package = package

  erb :thankyou
end
