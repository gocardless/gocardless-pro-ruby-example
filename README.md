# GoCardless Flow Demo App

A simple demo of using the GoCardless Pro redirect flow to serve hosted payment pages.

## Running Locally

    git clone https://github.com/gocardless/flow-demo-app
    cd flow-demo-app
    bundle install
    API_KEY_ID=XXX API_KEY_SECRET=XXX CREDITOR_ID=XXX bundle exec shotgun app.rb

Then open [http://localhost:9393/](http://localhost:9393/)
