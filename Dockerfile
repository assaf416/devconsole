FROM ruby:3.4-slim

ENV APP_HOME=/app \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test"

WORKDIR ${APP_HOME}

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libsqlite3-0 libsqlite3-dev pkg-config && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN mkdir -p db

EXPOSE 4567

CMD ["bundle", "exec", "rackup", "-p", "4567", "-o", "0.0.0.0"]
