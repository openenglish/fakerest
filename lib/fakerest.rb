require 'rubygems'
require 'yaml'
require 'fakerest/argumentsparser'
require 'fakerest/userrequests'
require 'fakerest/profileloader'
require 'webrick'
require 'webrick/https'
require 'openssl'

@@options = FakeRest::ArgumentsParser.new.parse(ARGV)

require 'sinatra'
require 'sinatra/base'

CERT_PATH = '/opt/CA/server/'

# set :port, options[:port]
set :views, @@options[:views]
set :public_folder, @@options[:uploads]
set :static, true
# set :run, true

@@profile_file_path = @@options[:config]



class MyServer  < Sinatra::Base
  set :environment, :development
  
  configure :development do |config|
    # @@dr = DynamicRoutes.new 
    # @@dr.load_dynamic_routes self
    profile_loader = FakeRest::ProfileLoader.new(self)
    profile_loader.load(@@profile_file_path, @@options)
    set :views, @@options[:views]
  
  end
    

  get "/requests/:count" do
    user_requests = FakeRest::UserRequests.user_requests
    requests_count = params[:count].to_i

    start_index =  requests_count > user_requests.count ? 0 : ((user_requests.count - requests_count))
    end_index = user_requests.count
    range = start_index..end_index

    requests_template = '<%= "No requests found" if user_requests.empty? %>
   <% user_requests.each do |request| %>
     <%= "<b>Method:</b> #{request.method} <b>Status:</b> #{request.response_status_code} <b>URL:</b> #{request.url}" %></br>
     <pre><%= request.body %></pre>
     <% if request.request_file_path != nil %>
       <a href="/<%= request.request_file_path%>"><%= request.request_file_path%></a><br/>
       Type: <%= request.request_file_type%>
     <% end %>
     <hr/>
   <% end %>'

   erb requests_template, :locals => {:user_requests => user_requests[range].reverse}
  end

  get "/" do
    template = '<div>
    Current Profile : <%= current_profile%> 
    </div>
    <br/>'
    erb template, :locals => {:current_profile => @@profile_file_path}
  end
end

webrick_options = {
        :Port               => 443,
        :Logger             => WEBrick::Log::new($stderr, WEBrick::Log::DEBUG),
        :DocumentRoot       => "/ruby/htdocs",
        :SSLEnable          => true,
        :SSLVerifyClient    => OpenSSL::SSL::VERIFY_NONE,
        :SSLCertificate     => OpenSSL::X509::Certificate.new(  File.open(File.join(CERT_PATH, "server.crt")).read),
        :SSLPrivateKey      => OpenSSL::PKey::RSA.new(          File.open(File.join(CERT_PATH, "server.key")).read),
        :SSLCertName        => [ [ "CN",WEBrick::Utils::getservername ] ],
        :app                => MyServer
}

Rack::Server.start webrick_options

