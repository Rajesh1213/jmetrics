class ApplicationController < ActionController::Base
  # require '../../lib/restclientjira.rb'
  include RestClientJira
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  def post_search(sub_url,payload)
    response = RestClientJira.post(sub_url, payload)
  end

  def get_search(sub_url)
    response = RestClientJira.get(sub_url)	  
  end
end
