require 'omniauth'
require 'omniauth-twitter'
require 'twitter'
require 'sinatra'

use OmniAuth::Strategies::Twitter, ENV['CONSUMER_KEY'], ENV['CONSUMER_SECRET']

enable :sessions

class SessionUser
  attr_accessor :id, :oauth_token, :oauth_token_secret

  def self.create_from_auth!(session, auth)
    session[:id] = auth["uid"]
    session[:oauth_token] = auth.credentials.token
    session[:oauth_token_secret] = auth.credentials.secret
    self.new(session)
  end

  def initialize(session)
    @id = session[:id]
    @oauth_token = session[:oauth_token]
    @oauth_token_secret = session[:oauth_token_secret]
  end

  def logged_in?
    @id && @oauth_token && @oauth_token_secret
  end
end


helpers do
  def current_user
    @current_user ||= SessionUser.new(session)
  end
end

get '/' do
  if current_user.logged_in?
    "Hi #{current_user.id}! <a href='/sign_out'>sign out</a>"
  else
    '<a href="/sign_in">sign in with Twitter</a>'
  end
end

get '/auth/:name/callback' do
  SessionUser.create_from_auth!(session, request.env["omniauth.auth"])
  redirect '/'
end

get '/sign_in/?' do
  redirect '/auth/twitter'
end

get '/sign_out' do
  session_end!
  redirect '/'
end
