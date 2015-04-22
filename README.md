# GoCardless Pro Ruby Example

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

This is a simple [Sinatra](http://www.sinatrarb.com/) application that uses the [GoCardless Pro API](https://developer.gocardless.com/pro/) to collect recurring payments for subscriptions using our [redirect flow](https://developer.gocardless.com/pro/#api-endpoints-redirect-flows). It also acts as an example usage of our [ruby client library](https://github.com/gocardless/gocardless-pro-ruby-example)

You can see the app running at [https://gocardless-pro-ruby-example.herokuapp.com](https://gocardless-pro-ruby-example.herokuapp.com).

## Running the app locally

First, register a sandbox account [here](https://manage-sandbox.gocardless.com/), and grab an API key and secret from the dashboard.

```
git clone https://github.com/gocardless/flow-demo-app
cd flow-demo-app
bundle install

export GC_API_KEY=...
export GC_API_SECRET=...
export GC_CREDITOR_ID=...
bundle exec shotgun app.rb
```

Then open [http://localhost:9393/](http://localhost:9393/)
