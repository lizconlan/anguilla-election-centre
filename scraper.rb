#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

base_url = 'http://www.caribbeanelections.com/ai/elections/'
start_page = "#{base_url}default.asp"

def get_page(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_election_list(start_page, base_url)
  pages = []
  doc = get_page(start_page)
  doc.css('a[href*="_results_"]/@href').map(&:text).uniq.each do |page|
    pages << "#{base_url}#{page}"
  end
  pages
end

def election_years(urls, term_length=5)
  years = []
  urls.each do |url|
    if url =~ /(\d{4})/
      years << $1.to_i
    end
  end
  years.sort
end

def create_terms(years, term_length=5)
  puts 'creating terms data...'
  term_years = years.dup
  term_years << term_years.last + term_years.last + term_length
  term_years.each_cons(2) do |s, e|
    puts "#{s}–#{e}"
    term = {
      id: s,
      name: "#{s}-#{e}",
      start_date: s,
      end_date: e,
    }
    ScraperWiki.save_sqlite([:id], term, 'terms')
  end
end

def scrape_constituency(url)
  doc = noko_for(url)
  constituency = noko.css('.Article02').text
  puts constituency
  noko.xpath('.//span[@class="votes" and contains(.,"Representatives")]/ancestor::table[1]/tr[2]//table/tr').drop(1).each do |tr|
    tds = tr.css('td')
    data = {
      name: tds[1].text.tidy,
      party: tds[2].text.tidy,
      term: tds[0].text.tidy,
      constituency: constituency,
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

def scrape_mp(url)
  doc = get_page(url)
  data = {
    image: doc.css('img[@src*="/people/"]').sort_by { |i| i.attr('width') }.first.attr('src'),
    facebook: doc.css('a.inside[@href*="facebook.com"]/@href').text,
  }
  data[:image] = URI.join(url, data[:image]).to_s unless data[:image].to_s.empty?
  data
end

def scrape_constituency(url)
  doc = get_page(url)
  constituency = doc.css('.Article02').text
  puts constituency
  doc.xpath('.//span[@class="votes" and contains(.,"Representatives")]/ancestor::table[1]/tr[2]//table/tr').drop(1).each do |tr|
    tds = tr.css('td')
    data = {
      name: tds[1].text.tidy,
      party: tds[2].text.tidy,
      term: tds[0].text.tidy,
      constituency: constituency,
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

def scrape_election(url)
  doc = get_page(url)
  doc.css('a[href*="/district/"]/@href').map(&:text).uniq.each do |page|
    scrape_constituency("#{base_url}#{page}")
  end
end


doc = get_page(start_page)
election_pages = scrape_election_list(start_page, base_url)

# store the term data
create_terms(election_years(election_pages))

puts ""
puts "creating constituency data"
election_pages.each do |election_page|
  # scrape and store election data
  scrape_election(election_page)
end
