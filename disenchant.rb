#!/usr/bin/env ruby

require "net/https"
require "base64"
require "json"

def run
    port, token = read_lockfile
    host = "https://127.0.0.1:#{port}"
    player_loot = []
    create_client(port) do |http|
        loot_req =  get_loot(host, http)
        set_headers(loot_req, token)
        loot_res = http.request loot_req
        player_loot = JSON.parse(loot_res.body)
        puts "Found #{player_loot.length} loot items"
        player_loot = player_loot.select do |loot|
            loot["disenchantLootName"] == "CURRENCY_champion" && loot["itemStatus"] == "OWNED"
        end
        puts "Filtered down to  #{player_loot.length} loot items that are owned champions"
    end
    
    threads = player_loot.map do |loot|
        Thread.new do
            create_client(port) do |disenchant_http|
                puts "Disenchanting #{loot["itemDesc"]} shards"
                disenchant_req = disenchant(host, disenchant_http, loot["lootName"], loot["count"])
                set_headers(disenchant_req, token)
                disenchant_http.request disenchant_req
            end
        end
    end

    threads.each(&:join)
end

def read_lockfile
    contents = File.read("lockfile")
    _leagueclient,_unkPort,port,password = contents.split(":")
    token = Base64.encode64("riot:#{password.chomp}")
    
    [port, token]
end

def create_client(port)
    Net::HTTP.start("127.0.0.1", port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
        yield(http)
    end
end

def set_headers(req, token)
    req['Content-Type'] = "application/json"
    req["Authorization"] = "Basic #{token.chomp}"
end

def get_loot(host, http)
    uri = URI("#{host}/lol-loot/v1/player-loot")
    Net::HTTP::Get.new(uri)
end

def disenchant(host, http, loot_name, repeat)
    uri = URI("#{host}/lol-loot/v1/recipes/CHAMPION_RENTAL_disenchant/craft?repeat=#{repeat}")
    req = Net::HTTP::Post.new(uri, 'Content-Type': "application/json")
    req.body = "[\"#{loot_name}\"]"
    req
end


run()