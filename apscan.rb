#/usr/bin/env ruby

# Original author: Peter Zingg
# Copyleft Kentfield School District, free use under Creative Commons license!

require 'yaml'

CONFIG = YAML.load(File.open('base_stations.yml')).freeze
BASE_STATION_DB = CONFIG['base_stations']
CLOSED_SSIDS_TO_SCAN = CONFIG['closed_ssids']

UNKNOWN_BS_INFO = {
  'model' => 'Unknown',
  'school' => 'Unknown',
  'room' => 'Unknown',
}.freeze

# The OUI part of a MAC address is the first 3 octets
# http://standards.ieee.org/develop/regauth/oui/oui.txt
# These are a few models we have at our school--pad these out if you
# have any further information!
OUI_DB = {
  '00:03:93' => 'Apple AirPort Extreme (A1034)',
  '00:07:40' => 'Buffalo WLA-G54',
  '00:11:24' => 'Apple AirPort Extreme with 802.11g',
  '00:16:01' => 'Buffalo WZR-AG300NH',
  '00:16:cb' => 'Apple AirPort Extreme with 802.11g',
  '00:1b:63' => 'Apple AirPort Express',
  '00:1c:b3' => 'Apple AirPort Extreme with 802.11n (Gigabit Ethernet)',
  '00:1f:33' => 'Netgear WG111v2',
  '00:1f:f3' => 'Apple AirPort Extreme with 802.11n (Gigabit Ethernet)',
  '00:21:f7' => 'HP ProCurve Unknown',
  '00:22:75' => 'Belkin Wireless',
  '00:24:a5' => 'Buffalo WHR-HP-G54',
  '00:25:3c' => '2Wire 3800 HGV-B U-verse Residential Gateway',
  '00:ff:66' => 'Unregistered Unknown',
  '30:46:9a' => 'Netgear WNDR3700',
  '3c:ea:4f' => '2Wire i3812V',
  '66:2a:2f' => 'Unregistered Unknown',
  '68:7f:74' => 'Linksys WRT54GL',
  'c0:3f:0e' => 'Netgear DG834G',
  'f8:1e:df' => 'Apple AirPort Extreme (Simultaneous Dual-Band II)',
}.freeze

# The very hard to remember location of Apple's airport commandline utility
AIRPORT_CMD = '/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport'

# lookup models based on OUI data above
def find_model(bssid)
  OUI_DB.fetch(bssid[0..7], "Unknown")
end

def wireless_scan(ssid)
  # puts "scanning #{ssid.nil? ? 'open networks' : ssid}"
  res = { }
  
  # --scan will scan for the specified (possibly closed) networks
  # --scan with no parameter will scan for open networks
  cmdline = "#{AIRPORT_CMD} --scan=#{ssid}"
  result_lines = IO.popen(cmdline, 'r') { |apio| apio.readlines }
  result_lines.each_with_index do |line, i|
    next if line.nil? || line.length < 40
    # Results are returned in a column-delimited format
    # SSID can include spaces in the name, so we need to get it from the
    # first 32 chars of the line; after that, we can use split for the 
    # rest.
    # 0 - SSID
    # 1 - BSSID (AirPort ID)
    # 2 - RSSI (signal strength)
    # 3 - CHANNEL
    # 4 - HT
    # 5 - CC
    # 6 - SECURITY (auth/unicast/group)
    ssid = line[0..31].strip
    bssid, rssi, channel, ht, cc, security = line[32..-1].strip.split(/\s+/)
    next if bssid == 'BSSID'
    
    # put results in a hash based on BSSID
    res[bssid] = { :ssid => ssid, :channel => channel.to_i, 
      :rssi => rssi.to_i, :ht => ht, :cc => cc, :security => security }
  end
  res
end

# scan and sort
def scan_ssids
  puts "Scan started #{Time.now.strftime("%a %b %d %Y at %I:%M %p")}"

  # First scan open networks
  all_bs = wireless_scan(nil)

  # Now scan closed networks and merge results based on bssid
  CLOSED_SSIDS_TO_SCAN.each do |ssid| 
    all_bs.merge!(wireless_scan(ssid))
  end
  
  # Now convert to array and sort results based on signal strength
  all_bs.to_a.sort do |a, b|
    b[1][:rssi] <=> a[1][:rssi]
  end
end

# print out results
def dump_results(all_bs)
  puts "Found #{all_bs.length} base station(s), listed by signal strength"
  puts " "
  all_bs.each do |bssid, this_bs|
    bs_info = BASE_STATION_DB[bssid] || 
      UNKNOWN_BS_INFO.dup.update('model' => find_model(bssid))
  
    puts bssid
    puts "    ssid: #{this_bs[:ssid]}"
    puts "   model: #{bs_info['model']}"
    puts "location: #{bs_info['school']} #{bs_info['room']}"
    puts " channel: #{this_bs[:channel]}"
    puts "strength: #{this_bs[:rssi]} db"
    puts " "
  end
end

# script starts here
all_bs = scan_ssids
dump_results(all_bs)
