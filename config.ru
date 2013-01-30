require './app'
use Rack::Static, :urls => ['/stylesheets', '/img'], :root => 'public'
run Sinatra::Application
