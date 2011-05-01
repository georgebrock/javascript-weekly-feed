require 'sinatra/base'
require 'erb'
require 'nokogiri'
require 'open-uri'

module JavascriptWeekly
  BASE_URL = 'http://javascriptweekly.com/archive'

  def latest_issue
    @latest_issue ||= (
      doc = Nokogiri::HTML(open(BASE_URL))
      doc.css('a').map{|l| l.text.to_i }.max
    )
  end

  def issue_url(number)
    '%s/%d.html' % [BASE_URL, number]
  end

  def issue(number)
  end

  extend self
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
    def latest_issue
      JavascriptWeekly.latest_issue
    end

    def first_relevant_issue
      latest_issue - 10
    end

    def issue_url(number)
      JavascriptWeekly.issue_url(number)
    end

    def issue_publication_date(number)
      1
    end

    def issue_content(number)
      '...'
    end
  end

end
