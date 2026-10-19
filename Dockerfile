# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.4.11
FROM ruby:${RUBY_VERSION}-slim

WORKDIR /rails

# Install essential dependencies for Rails and PostgreSQL
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      curl \
      git \
      libpq-dev \
      libyaml-dev \
      pkg-config \
      postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Bundler environment configuration
ENV BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_BIN="/usr/local/bundle/bin" \
    PATH="/rails/bin:/usr/local/bundle/bin:${PATH}"

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code
COPY . .

# Ensure entrypoint is executable
RUN chmod +x /rails/bin/docker-entrypoint

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
