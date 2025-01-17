FROM ruby:3.1.1

RUN apt-get update && apt-get install -y --no-install-recommends \
    npm \
    build-essential \
    git \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN npm install -g yarn@latest

WORKDIR /opt/webapps/app

COPY Rakefile Gemfile Gemfile.lock ./
# ADD vendor/gems/omniauth-tara ./vendor/gems/omniauth-tara
# ADD vendor/gems/omniauth ./vendor/gems/omniauth
RUN gem install bundler && bundle install --jobs 20 --retry 5

COPY package.json yarn.lock ./

# RUN yarn cache clean
RUN yarn install --check-files

