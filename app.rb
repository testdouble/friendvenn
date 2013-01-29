require 'omniauth'
require 'omniauth-twitter'
require 'sinatra'

use OmniAuth::Strategies::Twitter, ENV['CONSUMER_KEY'], ENV['CONSUMER_SECRET']

enable :sessions

helpers do
  def current_user_id
    @current_user ||= session[:user_id]
  end
end

get '/' do
  if current_user_id
    "Hi #{current_user_id}! <a href='/sign_out'>sign out</a>"
  else
    '<a href="/sign_in">sign in with Twitter</a>'
  end
end

get '/auth/:name/callback' do
  auth = request.env["omniauth.auth"]
  session[:user_id] = auth["uid"]
  redirect '/'
end

get '/sign_in/?' do
  redirect '/auth/twitter'
end

get '/sign_out' do
  session[:user_id] = nil
  redirect '/'
end
