# GoCardless Flow Demo App

A simple demo of using the GoCardless Pro redirect flow to serve hosted payment pages.

## Running Locally

    git clone https://github.com/gocardless/flow-demo-app
    cd flow-demo-app
    bundle install
    API_KEY_ID=x API_KEY_SECRET=x CREDITOR_ID=x bundle exec ruby app.rb

Then open [http://localhost:4567/](http://localhost:4567/)
