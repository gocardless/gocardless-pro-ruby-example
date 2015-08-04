require 'rubygems'
require 'sinatra'
require 'securerandom'
require 'json'

require 'prius'
require 'gocardless_pro'
require 'i18n'
require 'i18n/backend/fallbacks'
require 'rack'
require 'rack/contrib'
require 'pry'

# Load Environment Variables
Prius.load(:gc_access_token)

PACKAGE_PRICES = {
  "bronze" => { "GBP" => 100, "EUR" => 130 },
  "silver" => { "GBP" => 500, "EUR" => 700 },
  "gold" => { "GBP" => 1000, "EUR" => 1300 }
}

# Internationalisation by browser preference
use Rack::Locale

# Settings
set :session_secret, 'im_a_secret_yay!'
set :api_client, GoCardlessPro::Client.new(
  access_token: Prius.get(:gc_access_token),
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

  redirect_flow = settings.api_client.redirect_flows.create(params: {
    description: I18n.t(:package_description, package: package.capitalize),
    session_token: session[:token],
    success_redirect_url: success_url,
    scheme: params[:scheme],
  })
  redirect redirect_flow.redirect_url
end

# Customer returns from GC's payment pages
get '/payment_complete' do
  package = params[:package]
  redirect_flow_id = params[:redirect_flow_id]
  price = PACKAGE_PRICES.fetch(package)

  # Complete the redirect flow
  completed_redirect_flow = settings.api_client.redirect_flows.
    complete(redirect_flow_id, params: { session_token: session[:token] })

  mandate = settings.api_client.mandates.get(completed_redirect_flow.links.mandate)

  # Create the subscription
  currency = case mandate.scheme
             when "bacs" then "GBP"
             when "sepa_core" then "EUR"
             end

  subscription = settings.api_client.subscriptions.create(params: {
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
  })

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
  @first_payment_date = subscription.upcoming_payments.first["charge_date"]
  @package = package

  erb :thankyou
end
