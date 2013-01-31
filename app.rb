require 'omniauth'
require 'omniauth-twitter'
require 'twitter'
require 'sinatra'
require 'dalli'
require 'memcachier'
require 'ostruct'

use OmniAuth::Strategies::Twitter, ENV['CONSUMER_KEY'], ENV['CONSUMER_SECRET']
use Rack::Logger

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

  def logger
    request.logger
  end

  def cache
    settings.cache
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

set :cache, Dalli::Client.new(nil, :expires_in => 3600)

get '/' do
  if current_user.logged_in?
    erb :query
  else
    erb :welcome
  end
end

get '/comparison' do
  return redirect '/' unless current_user.logged_in?
  return erb :query unless valid_comparison?

  user_1_name = params[:user_1].gsub('@','')
  user_2_name = params[:user_2].gsub('@','')

  #find the common friends
  common_friend_ids = fetch_friend_ids(user_1_name) & fetch_friend_ids(user_2_name)

  user_keys = [:id, :handle, :profile_image_url]
  @common_friends = fetch_users(common_friend_ids, user_keys).sort_by{ |u| u.handle.downcase }
  @user_1         = fetch_users([user_1_name], user_keys).first
  @user_2         = fetch_users([user_2_name], user_keys).first

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

def valid_comparison?
  param_defined?(:user_1) && param_defined?(:user_2)
end

def param_defined?(name)
  params[name] && !params[name].empty?
end

def fetch_friend_ids(user_id)
  cache.fetch("twitter:friend_ids:#{user_id}") {
    Twitter.friend_ids(user_id).to_a
  }
end

def fetch_users(user_ids, include_keys)
  cached_users = []
  ids_to_prime = []

  user_ids.each do |user_id|
    user = fetch_user(user_id, include_keys)
    if user
      cached_users << user
    else
      ids_to_prime << user_id
    end
  end

  # get the remainder of the users from the twitter api, and cache them,
  # and add them to the cached user list. Wow... this does a lot of stuff
  get_users_from_twitter(ids_to_prime).each do |user|
    user_attributes = strip_user(user, include_keys)
    cache_user(user_attributes, include_keys)
    cached_users << user_attributes
  end

  # make the user hashes "objecty"
  cached_users.map do |user|
    OpenStruct.new(user)
  end
end

def strip_user(user, include_keys)
  user_attributes = include_keys.reduce({}) do |attrs, key|
    attrs[key] = user.send(key)
    attrs
  end
end

def user_cache_key(user_id, include_keys)
  "twitter:users:#{user_id}:#{include_keys.hash}"
end

def fetch_user(user_id, include_keys)
  cache.get(user_cache_key(user_id, include_keys))
end

# cache a user by both id and handle
def cache_user(user, include_keys)
  cache.set(user_cache_key(user['id'], include_keys), user)
  cache.set(user_cache_key(user['handle'], include_keys), user)
end

def get_users_from_twitter(user_ids)
  user_ids.each_slice(Twitter::API::Users::MAX_USERS_PER_REQUEST).map do |group|
    Twitter.users(*group, :method => :get)
  end.flatten
end
