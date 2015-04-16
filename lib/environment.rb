require 'prius'

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
