FROM ruby:2.4

WORKDIR /var/www

COPY . /var/www/

RUN bundle install
