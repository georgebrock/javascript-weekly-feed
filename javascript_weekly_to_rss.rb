require 'sinatra/base'
require 'erb'
require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'cgi'

module JavascriptWeekly
  BASE_URL = 'http://javascriptweekly.com/archive'

  def latest_issue_number
    @latest_issue ||= (
      doc = Nokogiri::HTML(open(BASE_URL))
      doc.css('a').map{|l| l.text.to_i }.max
    )
  end

  def issue(number)
    @issues ||= {}
    @issues[number] ||= JavascriptWeekly::Issue.new(number)
  end

  extend self
end

class JavascriptWeekly::Issue
  attr_reader :number

  def initialize(number)
    @number = number
    @last_modified, @content = nil, nil
  end

  def url
    '%s/%d.html' % [JavascriptWeekly::BASE_URL, number]
  end

  def content
    load if @content.nil?
    @content
  end

  def last_modified
    load if @last_modified.nil?
    @last_modified
  end

protected
  def load
    url = URI.parse(self.url)
    response = Net::HTTP.start(url.host, url.port){|http| http.get(url.path) }
    @content = Nokogiri::HTML::Document.parse(response.body).css('body').inner_html
    @last_modified = response['Last-Modified']
  end

end

class JavascriptWeeklyToRss < Sinatra::Base

  get '/' do
    erb :index
  end

  get '/atom.xml' do
    content_type 'application/atom+xml'
    erb :atom
  end

  helpers do
    def issues
      last_number = JavascriptWeekly.latest_issue_number
      first_number = last_number - 10
      (first_number..last_number).to_a.reverse.map{|n| JavascriptWeekly.issue(n) }
    end
  end

end
