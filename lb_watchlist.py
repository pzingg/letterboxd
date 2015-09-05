# Python 3

from bs4 import BeautifulSoup
from urllib.request import urlopen
import csv

films = [ ]
base_url = "http://letterboxd.com"

# Grab film slugs
page_url = "/pzingg/watchlist"
while True:
  print("watchlist %s" % page_url)
  
  page = urlopen(base_url + page_url)
  soup = BeautifulSoup(page.read(), 'html.parser')

  film_list = soup.find('ul', class_='film-list')
  if film_list is None:
    break

  film_posters = film_list.find_all('div', class_='film-poster')
  for film in film_posters:
    film_url = film.get('data-film-slug')
    if film_url is not None:
      films.append(film_url)

  next_link = soup.find('a', class_='paginate-next')
  if next_link is None:
    break
  page_url = next_link['href']


# Visit film pages and get metadata
with open('data/pzingg_watchlist.csv', 'w') as csvfile:
  csv = csv.DictWriter(csvfile, fieldnames=['id', 'name', 'year', 'letterboxd_url'], quoting=csv.QUOTE_ALL)
  csv.writeheader()
  for page_url in films:
    print("film %s " % page_url)

    page = urlopen(base_url + page_url)
    soup = BeautifulSoup(page.read(), 'html.parser')

    film = soup.find('div', class_='film-poster')
    if film is not None:
      # url is also in film.get('data-film-link')
      csv.writerow( { 
        'id':   film.get('data-film-id'),
        'name': film.get('data-film-name'),
        'year': film.get('data-film-release-year'),
        'letterboxd_url': page_url
      } )
