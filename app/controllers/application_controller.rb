class ApplicationController < ActionController::Base
  require 'rest_client'
  require 'json'
  require 'time'
  require 'restclientjira.rb'
  include RestClientJira
  helper_method :get_projects_list
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def post_search(sub_url,payload)
    response = RestClientJira.post(sub_url, payload)
  end

  def get_search(sub_url)
    response = RestClientJira.get(sub_url)	  
  end

  def get_date(date_hash)
    return "#{date_hash['year']}-#{date_hash['month']}-#{date_hash['day']}"
  end

  def get_projects_list
    res = get_search('project')
    JSON.parse(res).collect{|ele| [ele['name'],ele['key']]}
  end
end
