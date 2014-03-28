# Require the bundler gem and then call Bundler.require to load in all gems
# listed in Gemfile.
require 'warden'
require 'bundler'
require 'pp'
Bundler.require

# Setup DataMapper with a database URL. On Heroku, ENV['DATABASE_URL'] will be
# set, when working locally this line will fall back to using SQLite in the
# current directory.
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/development.sqlite")

# Define a simple DataMapper model.
class Thing
  include DataMapper::Resource

  property :id, Serial, :key => true
  property :created_at, DateTime
  property :title, String, :length => 255
  property :description, Text
end

# Finalize the DataMapper models.
DataMapper.finalize

# Tell DataMapper to update the database according to the definitions above.
DataMapper.auto_upgrade!

get '/' do
  send_file './public/index.html'
end

# Route to show all Things, ordered like a blog
get '/things' do
  env['warden'].authenticate!(:access_token)

  content_type :json
  @things = Thing.all(:order => :created_at.desc)

  @things.to_json
end

get '/things/public' do
  content_type :json
  @things = Thing.all(:title.like => "Test%")

  @things.to_json
end

# CREATE: Route to create a new Thing
post '/things' do
  env['warden'].authenticate!(:access_token)

  content_type :json

  # These next commented lines are for if you are using Backbone.js
  # JSON is sent in the body of the http request. We need to parse the body
  # from a string into JSON
  # params_json = JSON.parse(request.body.read)

  # If you are using jQuery's ajax functions, the data goes through in the
  # params.
  @thing = Thing.new(params)

  if @thing.save
    @thing.to_json
  else
    halt 500
  end
end

# READ: Route to show a specific Thing based on its `id`
get '/things/:id' do
  env['warden'].authenticate!(:access_token)

  content_type :json
  @thing = Thing.get(params[:id].to_i)

  if @thing
    @thing.to_json
  else
    halt 404
  end
end

# UPDATE: Route to update a Thing
put '/things/:id' do
  env['warden'].authenticate!(:access_token)

  content_type :json

  # These next commented lines are for if you are using Backbone.js
  # JSON is sent in the body of the http request. We need to parse the body
  # from a string into JSON
  # params_json = JSON.parse(request.body.read)

  # If you are using jQuery's ajax functions, the data goes through in the
  # params.

  @thing = Thing.get(params[:id].to_i)
  @thing.update(params)

  if @thing.save
    @thing.to_json
  else
    halt 500
  end
end

# DELETE: Route to delete a Thing
delete '/things/:id/delete' do
  env['warden'].authenticate!(:access_token)

  content_type :json
  @thing = Thing.get(params[:id].to_i)

  if @thing
    if @thing.destroy
      {:success => "ok"}.to_json
    else
      halt 500
    end
  else
    halt 404
  end
end

# This is the route that unauthorized requests gets redirected to.
post '/unauthenticated' do
  content_type :json
  json({ message: "Sorry, this request can not be authenticated. Try again." })
end

# Configure Warden
use Warden::Manager do |config|
  config.scope_defaults :default,
    # Set your authorization strategy
    strategies: [:access_token],
    # Route to redirect to when warden.authenticate! returns a false answer.
    action: '/unauthenticated'
  config.failure_app = self
end

#Warden::Manager.before_failure do |env,opts|
#  env['REQUEST_METHOD'] = 'POST'
#end

# Implement your Warden stratagey to validate and authorize the access_token.
Warden::Strategies.add(:access_token) do
  def valid?
    # Validate that the access token is properly formatted.
    # Currently only checks that it's actually a string.
    request.env["HTTP_ACCESS_TOKEN"].is_a?(String)
  end

  def authenticate!
    # Authorize request if HTTP_ACCESS_TOKEN matches 'youhavenoprivacyandnosecrets'
    # Your actual access token should be generated using one of the several great libraries
    # for this purpose and stored in a database, this is just to show how Warden should be
    # set up.
    access_granted = (request.env["HTTP_ACCESS_TOKEN"] == 'youhavenoprivacyandnosecrets')
    !access_granted ? fail!("Could not log in") : success!(access_granted)
  end
end

# If there are no Things in the database, add a few.
if Thing.count == 0
  Thing.create(:title => "Test Thing One", :description => "Sometimes I eat pizza.")
  Thing.create(:title => "Test Thing Two", :description => "Other times I eat cookies.")
end
