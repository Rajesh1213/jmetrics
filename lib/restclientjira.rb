module RestClientJira
  USERNAME = ''
  PASSWORD = ''

  #this is a old url  
  REQUEST_URL = "https://seneca-global.atlassian.net/rest/api/2"
  
  def self.auth
    rest_client = RestClient::Resource.new REQUEST_URL, USERNAME, PASSWORD
  end
    
  def self.get(sub_url)
    response = self.auth[sub_url].get
  end
  
  def self.post(sub_url, payload)
    response = self.auth[sub_url].post payload, :content_type => 'application/json'
  end 

end