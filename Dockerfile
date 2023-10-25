## COOKBOOK DEPENDENCIES

FROM dart:2.19.0 as dart-base
WORKDIR /code

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    software-properties-common \
    zlib1g-dev \
    shellcheck \
    wget \
    gpg \
    gpg-agent \
    procps \
    && rm -rf /var/lib/apt/lists/*

# # Install a quick colorized prompt and turn on ls coloring
RUN git clone https://github.com/nojhan/liquidprompt.git ~/liquidprompt && \
    echo '[[ $- = *i* ]] && source ~/liquidprompt/liquidprompt' >>~/.bashrc && \
    mkdir -p ~/.config && \
    echo 'export LP_HOSTNAME_ALWAYS=1' >>~/.config/liquidpromptrc && \
    echo 'export LP_USER_ALWAYS=-1' >>~/.config/liquidpromptrc && \
    sed -i "/color=auto/"' s/# //' ~/.bashrc && \
    sed -i "/alias ls/,/lA/"' s/# //' ~/.bashrc

# ---------------------------
# Additional dart dependencies
# ---------------------------
COPY \
    ./ce-styles/package.json \
    ./ce-styles/yarn.lock \
    ./ce-styles/pubspec.* \
    /code/ce-styles/

RUN dart pub get --directory /code/ce-styles

# ---------------------------
# Install ruby
# ---------------------------
ENV RUBY_VERSION=3.2.2

RUN curl -fsSL https://rvm.io/mpapis.asc | gpg --import - \
    && curl -fsSL https://rvm.io/pkuczynski.asc | gpg --import - \
    && curl -fsSL https://get.rvm.io | bash -s stable

# RUN source /usr/local/rvm

RUN bash -lc " \
        rvm requirements \
        && rvm install ${RUBY_VERSION} \
        && rvm use ${RUBY_VERSION} --default \
        && rvm rubygems current \
        && gem install bundler --no-document"
RUN echo "rvm_gems_path=/workspace/.rvm" > ~/.rvmrc
ENV PATH=$PATH:/usr/local/rvm/rubies/ruby-${RUBY_VERSION}/bin/
ENV GEM_HOME=/usr/local/rvm/gems/ruby-${RUBY_VERSION}
ENV GEM_PATH=/usr/local/rvm/gems/ruby-${RUBY_VERSION}:/usr/local/rvm/gems/ruby-${RUBY_VERSION}@global

ARG bundler_version

COPY ./cookbook/ /code/cookbook

RUN gem install bundler --no-document --version $bundler_version && \
    BUNDLE_GEMFILE='cookbook/Gemfile' bundle install && \
    # gem install solargraph && \
    gem install lefthook && \
    bundle config set no-cache 'true' && \
    bundle config set silence_root_warning 'true'


# Install node
# https://stackoverflow.com/questions/36399848/install-node-in-dockerfile/57546198#57546198
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
ENV NVM_DIR=/root/.nvm
ENV NODE_VERSION=20.8.0
RUN . "$NVM_DIR/nvm.sh" && nvm install $NODE_VERSION && \
    . "$NVM_DIR/nvm.sh" && nvm use v$NODE_VERSION && \
    . "$NVM_DIR/nvm.sh" && nvm alias default v$NODE_VERSION
ENV PATH="/root/.nvm/versions/node/v$NODE_VERSION/bin/:${PATH}"


# Install yarn
#
# When you run npm as root (this is the default user in Docker build) and
# install a global package, for security reasons, npm installs and executes
# binaries as user nobody, who doesn't have any permissions. This is for
# security reasons.
#
# Get around this by adding the --unsafe-perm flag
RUN npm install --global --unsafe-perm yarn

# Post-install builds the styles/output/_web-styles.json
# which is not needed for being in a docker container.
ENV SKIP_MY_POSTINSTALL=true

# Install code
COPY . ./
