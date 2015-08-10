#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'colorize'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_mp(url)
  noko = noko_for(url)
  data = {
    image: noko.css('img[@src*="/people/"]').sort_by { |i| i.attr('width') }.first.attr('src'),
    facebook: noko.css('a.inside[@href*="facebook.com"]/@href').text,
    wikipedia: noko.css('a.inside[@href*="wikipedia"]/@href').text,
  }
  data[:image] = URI.join(url, data[:image]).to_s unless data[:image].to_s.empty?
  return data
end

def scrape_list(url)
  noko = noko_for(url)
  noko.css('a[href*="/districts/"]/@href').map(&:text).uniq.reject { |t| t.include? '/default' }.each do |constit|
    scrape_constituency URI.join(url, constit)
  end
end

def scrape_constituency(url)
  noko = noko_for(url)
  constituency = noko.css('.Article02').text
  puts constituency
  noko.xpath('.//tr[contains(.,"Year") and contains(.,"Winner")]').last.xpath('.//following-sibling::tr').each do |tr|
    tds = tr.css('td')
    name = tds[2].text.tidy.split(',').reverse
    family_name = name.pop
    given_name = name.reverse.join.tidy
    data = {
      name: "#{given_name} #{family_name}",
      full_name: "#{given_name} #{family_name}",
      family_name: family_name,
      given_name: given_name,
      party: tds[3].text.tidy,
      term: tds[0].text.tidy,
      area: constituency[/District (\d+): (.*)/, 2],
      area_id: constituency[/District (\d+): (.*)/, 1],
      source: url.to_s,
    }
    mp_link = tds[1].css('a/@href')
    unless mp_link.to_s.empty?
      new_data = scrape_mp(URI.join(url, mp_link.text))
      data.merge! new_data
    end
    # puts data
    ScraperWiki.save_sqlite([:name, :term], data)
  end
end

%w(1989 1994 1999 2000 2005 2010 2015 2020).each_cons(2) do |s, e|
  term = {
    id: s,
    name: "#{s}–#{e}",
    start_date: s,
    end_date: e,
  }
  ScraperWiki.save_sqlite([:id], term, 'terms')
end

scrape_list('http://www.caribbeanelections.com/ai/election2015/candidates/default.asp')
