require 'rubygems'
require 'net/http'
require 'json'
require 'csv'
require 'time'
require 'date'

twitters = [
  {:screen_name => "NicolasSarkozy", :followers => []},
  {:screen_name => "nadine__morano", :followers => []}
]
#twitters = [{:screen_name => "alx", :followers => []},{:screen_name => "tetalab", :followers => []}]

puts "Twitter intersection for #{twitters.map{|twitter| twitter[:screen_name]}.join(", ")}"

def remaining_api_calls
  resp = Net::HTTP.get_response(URI.parse("http://api.twitter.com/1/account/rate_limit_status.json"))
  json = JSON.parse(resp.body)
  remaining_hits = json["remaining_hits"] 
  if remaining_hits == 0
    sleep_time = (Time.parse(json["reset_time"]) - Time.now).to_i + 1
    puts "no more hits - sleeps #{sleep_time} seconds until reset at #{Time.parse(json["reset_time"])}"
    sleep sleep_time
    remaining_hits = 1
  end
  return remaining_hits
end

def request_json(url)
  if remaining_api_calls > 0
    begin
      resp = Net::HTTP.get_response(URI.parse(url))
      json = JSON.parse(resp.body)
      return json
    rescue
      return nil
    end
  else
    return nil
  end
end

#
# Get common followers
#
def common_followers(twitters)
  twitters.each do |twitter|
    url = "http://api.twitter.com/1/followers/ids.json?screen_name=#{twitter[:screen_name]}"
    cursor = -1
    begin
      puts url + "&cursor=#{cursor}"
      if json = request_json(url + "&cursor=#{cursor}")
        twitter[:followers] |= json["ids"]
        cursor = json["next_cursor"]
      else
        cursor = 0
      end
    end while cursor != 0
  end

  common_followers = []
  twitters.each do |twitter|
    common_followers = common_followers.empty? ? twitter[:followers] : twitter[:followers] & common_followers
  end
  puts "number of common followers: #{common_followers.size}"
  return common_followers
end

#
# Analyse common followers
#
def fetch_data(followers)
  data = []
  follower_packets = 100
  
  puts "Followers to fetch: #{followers}"

  while !followers.empty?
    url = "http://api.twitter.com/1/users/lookup.json?user_id=" + followers.pop(follower_packets).join(",")
    if json = request_json(url)
      data |= json
    end
  end
  return data
end

def create_csv(filename, data)
  puts "status\tfollow\tfriends\tname"
  CSV.open(filename, "ab") do |csv|
    data.sort{|a, b| a["statuses_count"]<=>b["statuses_count"]}.each do |screen|
      csv << screen.values
    end
  end
end

def existing_followers(filename)
  return CSV.read(filename).map{|t| t.first.to_i}
end

filename = twitters.map{|twitter| twitter[:screen_name]}.join("-") + ".csv"
followers = common_followers(twitters)
followers -= existing_followers(filename)
data = fetch_data(followers)
create_csv(filename, data)
