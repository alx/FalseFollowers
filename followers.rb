require 'rubygems'
require 'net/http'
require 'json'
require 'csv'
require 'time'
require 'date'
require 'googlecharts'

def remaining_api_calls
  begin
    resp = Net::HTTP.get_response(URI.parse("http://api.twitter.com/1/account/rate_limit_status.json"))
    json = JSON.parse(resp.body)
    remaining_hits = json["remaining_hits"] 
    #if remaining_hits == 0
    #  sleep_time = (Time.parse(json["reset_time"]) - Time.now).to_i + 1
    #  puts "no more hits - sleeps #{sleep_time} seconds until reset at #{Time.parse(json["reset_time"])}"
    #  sleep sleep_time
    #  remaining_hits = 1
    #end
    return remaining_hits
  rescue
    return 0
  end
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
  
  puts "Followers to fetch: #{followers.size}"

  while !followers.empty?
    url = "http://api.twitter.com/1/users/lookup.json?user_id=" + followers.pop(follower_packets).join(",")
    if json = request_json(url)
      data |= json
    end
  end
  return data
end

def create_csv(filename, data)
  CSV.open(filename, "ab") do |csv|
    data.sort{|a, b| a["statuses_count"]<=>b["statuses_count"]}.each do |screen|
      csv << screen.values
    end
  end
end

def existing_followers(filename)
  return CSV.read(filename).map{|t| t.first.to_i}
end

def create_csv_data(twitters, filename)
  followers = common_followers(twitters)
  followers -= existing_followers(filename)
  data = fetch_data(followers)
  create_csv(filename, data)
end

def analyse_csv_data(filename)
  twitters = CSV.read(filename)
  puts "before filter : #{twitters.size}"
  followings = {:max => 99999999, :min => 0, :total => 0}
  row_id = 0
  row_created_at = 2
  row_tweet_count = 30
  row_followers_count = 7
  row_following_count = 35
  twitters.select! do |twitter|
    twitter[row_tweet_count].to_i < 2 &&
    twitter[row_followers_count].to_i < 2
  end
  puts "after filter : #{twitters.size}"
  puts twitters.first.inspect

  dates = {}
  full_dates = {}

  twitters.each do |twitter|
    begin
      datetime = DateTime.parse(twitter[row_created_at]).strftime("%Y%m%d")
      if dates[datetime]
        dates[datetime] += 1
      else
        dates[datetime] = 1
      end
    rescue
      # puts twitter.inspect
    end
  end
  dates.reject!{|k,v| k=="18164834670109"}
  start_date = DateTime.parse "19/11/2008"
  end_date = DateTime.parse "20/02/2012"

  while start_date < end_date
    full_dates[start_date.strftime("%Y%m%d")] = dates[start_date.strftime("%Y%m%d")] || 0
    start_date += 1
  end

  puts Gchart.line(:data => full_dates.values, :size => "500x200")
end

twitters = [
  {:screen_name => "NicolasSarkozy", :followers => []},
  {:screen_name => "nadine__morano", :followers => []}
]
#twitters = [{:screen_name => "alx", :followers => []},{:screen_name => "tetalab", :followers => []}]

filename = twitters.map{|twitter| twitter[:screen_name]}.join("-") + ".csv"

puts "Twitter intersection for #{twitters.map{|twitter| twitter[:screen_name]}.join(", ")}"

# create_csv_data(twitters, filename)
analyse_csv_data(filename)
