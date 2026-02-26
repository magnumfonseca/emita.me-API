FROM ruby:3.3.4

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      curl \
      git \
      libpq-dev \
      libvips-dev \
      postgresql-client \
    && rm -rf /var/lib/apt/lists/*

RUN gem update --system && gem install bundler

WORKDIR /workspaces/emita.me

CMD ["sleep", "infinity"]
