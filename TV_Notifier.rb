# Ryan Bega - TV_Notifier.rb

require 'json'
require 'inifile'
require_relative 'helper_functions'

#Read Conf
conf = IniFile.load('TV_Notifier.conf')
response = Helper.authenticate(conf)

case response.code
when 200
  token = JSON.parse(response)["token"]
  auth = {
    'accept': 'json',
    'Authorization': 'Bearer ' + token
  }

  sID = Helper.showIDs(conf, auth)
  airing = Helper.getEps(sID, auth)
  Helper.email(airing, conf)
when 401
  #Access Denied
else

end


#Email with results
