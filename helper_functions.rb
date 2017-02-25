# Ryan Bega - helper functions for TV_Notifier
require 'json'
require 'inifile'
require 'addressable/uri'
require 'rest-client'
require 'net/smtp'

module Helper
  # Authenticate to TVDB api
  def Helper.authenticate (conf)

    url = 'https://api.thetvdb.com/login'
    data = {'apikey': conf['tvdb']['apikey']}
    headers = {
      'content_type': "application/json",
      'accept': 'json'
    }
    return RestClient.post(url, data.to_json, headers)
  end

  # Generate list of TVDB show IDs
  def Helper.showIDs (conf, auth)

    if(File.exists?(conf['default']['install_dir'] + 'shows.json'))
      # Read in hash of show title -> TVDB ID
      sID = JSON.parse(File.read(conf['default']['install_dir'] + 'shows.json'))
    else
      sID = Hash.new
    end

    Dir.chdir(conf['default']['media_dir'])
    Dir.glob('*').each do |show|
      # Search tvdb api for show ID if ID isn't already stored locally
      if(!sID.has_key?(show))
        url = Addressable::URI.encode_component('https://api.thetvdb.com/search/series?name=' + show)
        response = RestClient.get(url, auth)
        if response.code == 200
          search = JSON.parse(response)['data']
          search.each do |result|
            if show.downcase.eql?(result['seriesName'].downcase.gsub(/[*?=<>|:]/, ''))
              sID[show] = result['id']
            end
          end
        else
          puts 'error occurred in search for: ' + show
        end
      end
    end

    # Save hash of title -> TVDB id to disk
    Dir.chdir(conf['default']['install_dir'])
    File.open(conf['default']['install_dir'] + 'shows.json', 'w') do |f|
      f.write(JSON.pretty_generate(sID))
    end

    return sID
  end

  # Generate list of episodes airing today
  def Helper.getEps (sID, auth)
    #Date string for the day yyyy-mm-dd
    today = Time.new.strftime('%F')
    airing = Array.new

    #for each show ID query episodes firstAired to see if an ep aired today push to array
    sID.each do |title, id|
      url = 'https://api.thetvdb.com/series/' + id.to_s + '/episodes/query?firstAired=' + today
      RestClient.get(url, auth) do |response, request, result|
        if(response.code == 200)
          search = JSON.parse(response)['data']
          search.each do |ep|
            epStr = title + ': ' + ep['airedSeason'].to_s + 'x' + ep['airedEpisodeNumber'].to_s + ' - ' + ep['episodeName']
            airing.push(epStr)
          end
        end
      end
    end
    #return array of airing episodes
    return airing
  end

  # email list of airing episodes to supplied address
  def Helper.email (airing, conf)
    msg = "Subject: TV Airing Today\n\n"
    if(airing.length() > 0)
      airing.each do |ep|
        msg += ep + "\n"
      end
    else
      msg += "No new episodes air today"
    end

    mail_server = conf['email']['smtp_server'] + ':' + conf['email']['smtp_port'].to_s

    smtp = Net::SMTP.new(conf['email']['smtp_server'], conf['email']['smtp_port'])
    smtp.enable_starttls
    smtp.start(mail_server, conf['email']['from_email'], conf['email']['email_password'], :login) do
      smtp.send_message(msg, conf['email']['from_email'], conf['email']['to_email'])
    end
  end
end
