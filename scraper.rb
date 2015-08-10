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
  begin
    noko = noko_for(url)
  rescue
    return nil
  end
  data = {
    image: noko.css('img[@src*="/people/"]').sort_by { |i| i.attr('width') }.last.attr('src'),
    # facebook: noko.css('a.inside[@href*="facebook.com"]/@href').text,
    # wikipedia: noko.css('a.inside[@href*="wikipedia"]/@href').text,
  }
  data[:image] = URI.join(url, data[:image]).to_s unless data[:image].to_s.empty?
  # puts data
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
    sort_name = tds[2].text.tidy
    # manual correction for Othlyn Vanterpool
    if sort_name == "VANTERPOOL, Othyn"
      sort_name = "VANTERPOOL, Othlyn"
    end
    # manual correction for Palmavon Webster
    if sort_name == "WEBSTER, Pamalvon"
      sort_name = "WEBSTER, Palmavon"
    end
    # manual correction for Cora Richardson-Hodge
    if sort_name == "RICARDSON-HODGE, Cora"
      sort_name = "RICHARDSON-HODGE, Cora"
    end
    # manual correction for Evan Gumbs
    if sort_name == "GUMBS, Evans"
      sort_name = "GUMBS, Evan"
    end
    split_name = sort_name.split(',').reverse
    family_name = split_name.pop
    given_name = split_name.reverse.join.tidy
    data = {
      name: "#{given_name} #{family_name}",
      full_name: "#{given_name} #{family_name}",
      family_name: family_name,
      given_name: given_name,
      sort_name: sort_name,
      party: tds[3].text.tidy,
      term: tds[0].text.tidy,
      area: constituency[/District (\d+): (.*)/, 2],
      area_id: constituency[/District (\d+): (.*)/, 1],
      source: url.to_s,
    }
    # as there appear to be no links to the MP info, try to construct one
    link_name = "#{given_name.gsub(/ [A-Z]\./,' ')} #{family_name}".tidy.gsub(" ", "_").gsub("-", "_")
    # manual override for Evans McNiel Rogers
    if link_name == "Evans_McNiel_ROGERS"
      link_name = "Evans_Rogers"
    end
    mp_link = "http://www.caribbeanelections.com/ai/election2015/candidates/#{link_name}.asp"

    unless mp_link.to_s.empty?
      new_data = scrape_mp(mp_link)
      data.merge! new_data if new_data
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
