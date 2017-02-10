# Ryan Bega - helper functions for TV_Notifier
require 'json'
require 'inifile'
require 'addressable/uri'
require 'rest-client'

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

    if(File.exists?('shows.json'))
      # Read in hash of show title -> TVDB ID
      sID = JSON.parse(File.read('shows.json'))
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
    File.open('shows.json', 'w') do |f|
      f.write(JSON.pretty_generate(sID))
    end

    return sID
  end

  def Helper.getEps (sID, auth)
    #Date string for the day yyyy-mm-dd
    today = Time.new.strftime('%F')
    airing = Array.new

    #for each show ID query episodes firstAired to see if an ep aired today push to array
    sID.each do |title, ID|
      url = 'https://api.thetvdb.com/series/' + ID + '/episodes/query?firstAired=' + today
      response = RestClient.get(url, auth)
      if(reponse.code == 200)
        search = JSON.parse(response)['data']
        search.each do |ep|
          epStr = title + ': ' + ep['airedSeason'].to_s + 'x' + ep['airedEpisodeNumber'].to_s + ' - ' + ep['episodeName']
          airing.push(epStr)
        end
      end
    end
    #return array of airing episodes
    return airing
  end
end
