require 'rest-client'
require 'nokogiri'
require 'iconv'
require 'json'
require 'ruby-progressbar'

get_url = "http://www.mcu.edu.tw/student/new-query/sel-query/qslist.asp"
post_url = "http://www.mcu.edu.tw/student/new-query/sel-query/qslist_1.asp"
detail_base_url = "https://tch.mcu.edu.tw/sylwebqry/pro10_22.aspx"

preload_url = "http://www.mcu.edu.tw/student/new-query/sel-query/query_0_1.asp?gdb=2&gyy=103"

r = RestClient.get preload_url
cookie = r.cookies

ic = Iconv.new("utf-8//translit//IGNORE","big5")
r = RestClient.get get_url, :cookies => cookie
doc = Nokogiri::HTML(ic.iconv(r.to_s))

error_urls = []
# 跳過不限
schs = doc.css('select[name="sch"] option')[1..-1].map{|k| k['value']}

courses = []
schs.each_with_index do |sch, ii|
  doc = Nokogiri::HTML(ic.iconv (RestClient.post(post_url, {:sch => sch}, :cookies => cookie)).to_s)
  rows = doc.css('table tr:not(:first-child)')

  # progress = ProgressBar.create(:title => "#{ii}", :total => rows.count)
  rows.each do |row|
    # progress.increment

    columns = row.css('td')
    type = columns[0].text
    course_regex = /(?<serial>\w{5})(\s+)(?<name>.+)/
    mat = columns[1].text.match(course_regex)

    serial_no = mat['serial'].gsub(/\s+/,'')
    course_name = mat['name']

    stu_class = columns[2].text.match(/\d+/).to_s
    detail_url = columns[4].css('a')[0]['href']
    sche_raw = columns[5].text
    raws = sche_raw.split('節')
    locs = columns[7].text.split("\n")

    schedule = {}
    periods = []
    if raws.count == 1 && raws[0].gsub(/\s+/, '') == ":"
      schedule = nil
    else # valid
      raws.each_with_index do |raw, i| # 星期 1 : 05  06
        rrrs = raw.split(':') # ["星期 1 ", " 05  06"]
        day = rrrs.first.match(/\d/).to_s # 1
        hours = rrrs.last.split(' ') # ["05", "06"]

        # then add into hash
        schedule[day] = [] if schedule[day].nil?
        schedule[day].concat hours
        # schedule = { "1" : ["05", "06"] }

        # new periods format
        hours.each do |period|
          chars = []
          chars << day
          chars << period
          chars << locs[i]
          periods << chars.join(',')
        end
      end
    end

    grade = Integer columns[6].text
    required = columns[8].text

    # 剩下幾個欄位就先沒弄了
    # 詳細頁面先抓書就好...沒時間啦ww
    # tcls=00101&tcour=00755&tyear=103&tsem=2&type=1
    # detail_url = "#{detail_base_url}?tcls=#{stu_class}&tcour=#{serial_no}&tyear=103&teac=&tsem=2&type=1"
    # begin
    #   doc = Nokogiri::HTML((RestClient.get(detail_url, :cookies => cookie)).to_s)
    #   book = doc.css('#panShow1 tr:nth-child(7) td').text.strip
    # rescue Exception => e
    #   puts detail_url
    #   error_urls << detail_url
    #   book = nil
    # end

    courses << {
      # :type => type,
      :code => serial_no,
      :name => course_name,
      :department => stu_class,
      :url => detail_url,
      # :schedule => schedule,
      :periods => periods,
      # :grade => grade,
      # :classroom => locs,
      :required => required,
      # :book => book
    }

  end

end

File.open('courses.json', 'w') {|f| f.write(JSON.pretty_generate(courses))}
# File.open('error_urls.json', 'w') {|f| f.write(JSON.pretty_generate(error_urls))}
