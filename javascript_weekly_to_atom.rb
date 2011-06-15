require 'sinatra/base'
require 'erb'
require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'cgi'

# A weekly newsletter, currently either JavaScript Weekly or
# Ruby Weekly.
class Weekly

  URLS = {
    'javascript' => 'http://javascriptweekly.com/archive/',
    'ruby' => 'http://rubyweekly.com/archive/'
  }

  # Returns an instance for a given type.
  # The types should be keys in the Weekly::URLs hash.
  def self.get(type)
    @cache ||= {}
    @cache[type] ||= (
      url = URLS[type] or raise 'Invalid feed type'
      new(url)
    )
  end

  def initialize(base_url)
    @base_url = base_url
  end

  # Scrapes the archive index page to get the latest
  # issue number.
  def latest_issue_number
    @latest_issue ||= (
      doc = Nokogiri::HTML(open(@base_url))
      doc.css('a').map{|l| l.text.to_i }.max
    )
  end

  # Gets a given issue number.
  # This method will always return the same instance for each
  # number it's given.
  def issue(number)
    @issues ||= {}
    @issues[number] ||= Weekly::Issue.new(@base_url, number)
  end
end


# An single issue of a weekly newsletter.
# Does not hit the server until content or last_modified
# is called.
class Weekly::Issue
  attr_reader :number

  def initialize(base_url, number)
    @base_url = base_url
    @number = number
    @last_modified, @content = nil, nil
  end

  def url
    '%s/%d.html' % [@base_url, number]
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

  # Scrapes the issue page and populates instance variables with the results.
  # Called lazily when the results are required.
  def load
    url = URI.parse(self.url)
    response = Net::HTTP.start(url.host, url.port){|http| http.get(url.path) }
    @content = Nokogiri::HTML::Document.parse(response.body).css('body').inner_html
    @last_modified = response['Last-Modified']
  end

end

class WeeklyToAtom < Sinatra::Base

  get '/' do
    erb :index
  end

  get '/feeds/:type.xml' do
    type = params[:type]
    raise Sinatra::NotFound unless Weekly::URLS.keys.include?(type)

    recent_issues = issues(type)

    # Set the etag based on the type and the latest issue number
    # and possibly return a 304 (not modifed).
    # The issue content is lazily loaded, so at this point we've only
    # made one request to the root archive page.
    etag '%s_%d' % [type, recent_issues.first.number]

    # If the etag is missing or stale, build the page.
    # Cache the result for one day.
    content_type 'application/atom+xml'
    last_modified recent_issues.first.last_modified
    cache_control :public, :max_age => 86400
    erb :atom, :locals => {:type => type, :issues => recent_issues}
  end

  helpers do
    # Builds an array of the latest 10 issues of the given type.
    # Assumes that we only every use one type per request.
    def issues(type)
      @issues ||= (
        last_number = Weekly.get(type).latest_issue_number
        first_number = last_number - 10
        (first_number..last_number).to_a.reverse.map{|n| Weekly.get(type).issue(n) }
      )
    end
  end

  # We need to support this old URL for people who have
  # already subscribed.
  get '/atom.xml' do
    redirect to('/feeds/javascript.xml'), 301
  end

end
