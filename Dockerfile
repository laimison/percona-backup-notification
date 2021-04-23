FROM ruby:2.7.3

USER root

RUN apt-get update -qq \
  && DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends build-essential git-core jq less vim

RUN echo 'set mouse-=a' >> /root/.vimrc
RUN echo 'syntax enable' >> /root/.vimrc

RUN mkdir /app
WORKDIR /app

COPY Gemfile* ./

RUN gem install bundler \
  && bundle install -j "$(getconf _NPROCESSORS_ONLN)"

COPY . /app

CMD ["bundle", "exec", "ruby", "app.rb"]
