#!/usr/bin/env ruby

require 'csv'
require 'nokogiri'
require 'open-uri'
require 'yaml'

watched = { }
row = 0
doc = Nokogiri::XML(File.new('RentalActivity.xml'))
doc.root.css('table#rhtable tr').each do |tr|
  row += 1
  title = nil
  tr.css('td').each_with_index do |td, i|
    case i
    when 0
      title_link = td.at_css('a')
      if title_link
        title = title_link.text()
      end
    when 3
      contents = td.text()
      m = contents.match(/^(\d\d)\/(\d\d)\/(\d\d)$/)
      if title && m
        watched_date = Date.new($3.to_i + 2000, $1.to_i, $2.to_i) - 1
        watched[title] = { 'venue' => 'netflix dvd', 'watched_date' => watched_date }
        puts "#{title} watched on #{watched_date}"
      end
    else
    end
  end
end

File.open('netflix.yml', 'w') do |out|
  YAML.dump(watched, out)
end
