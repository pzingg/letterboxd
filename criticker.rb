#!/usr/bin/env ruby

require 'csv'
require 'nokogiri'
require 'open-uri'
require 'yaml'
require 'rubyfish'

# LetterboxdURI	String (optional, the URI of the matching film or diary entry)
# tmdbID	Number (optional, eg. 27205)
# imdbID	String (optional, eg. tt1375666)
# Title	String (used for matching when no ID or URI is provided)
# Year	YYYY (optional, used for matching when no ID or URI is provided)
# Directors	String (optional, used for matching when no ID or URI is provided)*
# WatchedDate	YYYY-MM-DD (optional, creates a Diary Entry for this film on this day)
# CreatedDate	YYYY-MM-DD'T'HH:mm:ss.SSS'Z' (optional)
# For example: 2012-12-31T12:30:00.000Z
# Rating	Number (optional, rating out of 5 including 0.5 increments)
# Rating10	Number (optional, rating out of 10)
# Tags	String (optional, added to Diary Entry if WatchedDate is provided)*
# Review	Text/HTML (optional, allows the same HTML tags as the website, added to Diary Entry if WatchedDate is provided, otherwise added as a review with no specified date)*

# 100   2  0.1  5
#  98 149  6.0  5
#  93 347 14.0  4.5
#  90 493 20.0  4
#  88 343 13.9  3.5
#  83 522 21.1  3
#  80  93  3.8  2.5
#  78 111  4.5  2.5
#  73 178  7.2  2
#  70 190  7.7  1.5
#  60  34  1.4  1
#  50   8  0.3  0.5

class C2L 
  SCORE_TO_RATING = [
    [ 98, 5.0 ],
    [ 93, 4.5 ],
    [ 90, 4.0 ],
    [ 88, 3.5 ],
    [ 83, 3.0 ],
    [ 78, 2.5 ],
    [ 73, 2.0 ],
    [ 70, 1.5 ],
    [ 60, 1.0 ],
    [ 40, 0.5 ],
    [  0, 0.0 ]
  ]
  
  def self.get_rating(score)
    score = 0 if score < 0
    SCORE_TO_RATING.find { |sr| score >= sr.first }.last
  end
  
  # would like to unaccent vowels and consonants, too
  def self.canonical(title)
    title.downcase.gsub(/:.+$/, '').gsub(/[^0-9a-z]/, '')
  end

  def initialize
    @scores = { }
    @ratings = { }
    @count = 0
    @verified_date = Date.new(2012, 2, 16)
    @imdb_table = { }
    @netflix_table = { }
    @netflix_keys = [ ]
  end
  
  def read_data_tables
    if File.readable?('imdb.yml')
      t = YAML.load(File.open('imdb.yml'))
      @imdb_table = t if t
    end
    if File.readable?('netflix.yml')
      t = YAML.load(File.open('netflix.yml'))
      if t
        @netflix_table = t
        @netflix_keys = @netflix_table.keys.map { |k| [ self.class.canonical(k), k ] }
      end
    end
  end
  
  def write_imdb_table
    File.open('imdb.yml', 'w') do |out|
      YAML.dump(@imdb_table, out)
    end
  end
  
  def find_watched_info(title)
    if @netflix_table.key?(title)
      return @netflix_table[title]
    else
      closest_title = nil
      highest_match = 0.0
      title_to_match = self.class.canonical(title)
      @netflix_keys.each do |kk|
        d = RubyFish::Jaro.distance(title_to_match, kk[0])
        if d > highest_match
          highest_match = d
          closest_title = kk[1]
        end
      end
      if highest_match >= 0.9
        puts "^ closest match for #{title} is #{closest_title}, d=#{highest_match}"
        return @netflix_table[closest_title]
      end
    end
    return nil
  end

  def get_imdb_id(film_id, film_link, title, year)
    if !@imdb_table.key?(film_id)
      url = film_link.gsub('rating/pzingg$', '')
      sleep(0.05)
      doc = Nokogiri::HTML(open(url))
      imdb_a = doc.root.at_css('div#fi_info_imdb a')
      if imdb_a
        imdb_link = imdb_a.attr('href')
        m_imdb = imdb_link.match(/imdb\.com\/title\/([^\/]+)[\/]?$/)
        raise "no imdb id for '#{imdb_link}'" unless m_imdb
        @imdb_table[film_id] = {
          'title' => title,
          'year' => year,
          'imdb_id' => m_imdb[1]
        }
      end
    end
    @imdb_table[film_id]['imdb_id']
  end
  
  def create_letterboxd_csv(limit=0)
    read_data_tables
    begin
      CSV.open('letterboxd.csv', 'w') do |csv|
        csv << ['Title', 'Year', 'imdbID', 'WatchedDate', 'CreatedDate', 'Rating', 'Tags', 'Review']
        doc = Nokogiri::XML(File.new('rankings.xml'))
        doc.root.xpath('film').each do |film|
          film_id   = film.at('filmid').text().to_i
          film_link = film.at('filmlink').text()
          film_name = film.at('filmname').text()
          m_name    = film_name.match(/^\s*(.+)\((\d+)\)\s*$/)
          raise "no year for '#{filmname}'" unless m_name
          title = m_name[1].strip
          year  = m_name[2].to_i
          imdb_id      = get_imdb_id(film_id, film_link, title, year)
          review_date  = Date.parse(film.at('reviewdate').text())
          created_date = review_date.strftime('%Y-%m-%dT23:00:00.000Z')
          watched_date = review_date.strftime('%Y-%m-%d')
          tags = ''
          if review_date <= @verified_date && review_date.year > year + 3
            watched = find_watched_info(title)
            if watched
              watched_date = watched['watched_date']
              tags = watched['venue']
            else
              if year < 1965
                days_after_start = rand(1825)
                guessed_date = Date.new(1969, 10, 1) + days_after_start 
                watched_date = guessed_date.strftime('%Y-%m-%d')
                tags = 'yfs, estimated date'
              else 
                days_after_start = rand(year < 1990 ? 5475 : 365)
                guessed_date = Date.new(year, 12, 15) + days_after_start
                watched_date = guessed_date.strftime('%Y-%m-%d')
                tags = 'estimated date'
              end
            end
          end
    
          review = film.at('quote').text().gsub(/[\t\r\n]+/, ' ')
          score  = film.at('score').text().to_i
          rating = self.class.get_rating(score)
          # puts "title #{title} year #{year} imdb_id #{imdb_id} score #{score} rating #{rating}"
          csv << [title, year, imdb_id, watched_date, created_date, rating, tags, review]
          # statistics
          @scores[score] = (@scores[score] || 0) + 1
          @ratings[rating] = (@ratings[rating] || 0) + 1
          @count += 1
          break if @count == limit
        end
      end
    ensure
      write_imdb_table
    end
  end
  
  def find_films_with_score(s_min, s_max=-1)
    s_max = s_min if s_max < 0
    puts "films with scores between #{s_min} and #{s_max}"
    doc = Nokogiri::XML(File.new('rankings.xml'))
    doc.root.xpath('film').each do |film|
      score  = film.at('score').text().to_i
      next unless s_min <= score && score <= s_max
      film_id   = film.at('filmid').text().to_i
      film_link = film.at('filmlink').text()
      film_name = film.at('filmname').text()
      m_name    = film_name.match(/^\s*(.+)\((\d+)\)\s*$/)
      title = m_name[1].strip
      year  = m_name[2].to_i
      puts "#{title}\t(#{year})"
    end
  end

  def dump_stats
    puts "scores"
    @scores.keys.sort.reverse.each do |k|
      printf("%3d %3d %4.1f\n", k, @scores[k], @scores[k]*100.0/@count)
    end

    puts "ratings"
    @ratings.keys.sort.reverse.each do |k|
      printf("%3.1f %3d %4.1f\n", k, @ratings[k], @ratings[k]*100.0/@count)
    end
  end
end

limit = (ARGV[0] || 0).to_i
s_max = (ARGV[1] || -1).to_i
converter = C2L.new
converter.find_films_with_score(limit, s_max)

#converter.create_letterboxd_csv(limit)
#converter.dump_stats
