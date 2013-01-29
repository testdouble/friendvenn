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

before do
  if current_user.logged_in?
    Twitter.configure do |config|
      config.consumer_key = ENV['CONSUMER_KEY']
      config.consumer_secret = ENV['CONSUMER_SECRET']
      config.oauth_token = current_user.oauth_token
      config.oauth_token_secret = current_user.oauth_token_secret
    end
  end
end

get '/' do
  if current_user.logged_in?
    erb :query
  else
    erb :welcome
  end
end

get '/comparison' do
  return redirect '/' unless current_user.logged_in?

  @user_1 = params[:user_1]
  @user_2 = params[:user_2]
  @common_friend_ids = Twitter.friend_ids(@user_1).to_a & Twitter.friend_ids(@user_2).to_a

  erb :comparison
end

get '/auth/:name/callback' do
  SessionUser.create_from_auth!(session, request.env["omniauth.auth"])
  redirect '/'
end

get '/sign_in/?' do
  redirect '/auth/twitter'
end

get '/sign_out' do
  session.clear
  redirect '/'
end
