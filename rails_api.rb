run 'pgrep spring | xargs kill -9'

RED = "1;31"
GREEN = "1;32"
WHITE = "1;37"
BACKGROUND_BLACK = "40"
BACKGROUND_WHITE = "47"
puts GREEN

def color(text, color_code=RED, background_color=BACKGROUND_WHITE)
  puts "\e[#{background_color}m\e[#{color_code}m#{text}\e[0m"
end

color "Starting Rails API"

# GEMFILE
########################################
color "Updating Gemfile", WHITE, BACKGROUND_BLACK
inject_into_file 'Gemfile', before: 'group :development, :test do' do
  <<~RUBY
    gem 'rack-cors'
    gem 'devise'
    gem 'foreman'
    gem 'autoprefixer-rails'
    gem 'font-awesome-sass'
  RUBY
end

inject_into_file 'Gemfile', before: "# Call 'byebug' anywhere in the code to stop execution and get a debugger console" do
  <<~RUBY
    gem 'rspec'
    gem 'rspec-rails', '~> 5.0.0'
    gem 'shoulda-matchers', '~> 4.0'
    gem 'factory_bot_rails'
    gem 'pry-byebug'
    gem 'pry-rails'
    gem 'dotenv-rails'
  RUBY
end
color "Gemfile updated", GREEN, BACKGROUND_BLACK

# README
########################################
color "Updating README", WHITE, BACKGROUND_BLACK
markdown_file_content = <<-MARKDOWN
  Welcome to the rails api template
MARKDOWN
file 'README.md', markdown_file_content, force: true
color "README updated", GREEN, BACKGROUND_BLACK

# Generators
########################################
color "Updating Generators ", WHITE, BACKGROUND_BLACK
generators = <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :rspec, fixture: false
    generate.factory_bot dir: 'spec/factories/'
    generate.factory_bot suffix: "factory"
  end
RUBY
color "Updating application.rb", GREEN, BACKGROUND_BLACK

environment generators

# AFTER BUNDLE
########################################
color 'Running bundle install', WHITE, BACKGROUND_BLACK
after_bundle do
  rails_command 'db:drop db:create db:migrate'

  # Routes
  ########################################
  color 'Updating routes', WHITE, BACKGROUND_BLACK
  insert_into_file 'config/routes.rb', after: "Rails.application.routes.draw do\n" do
    <<~RUBY
      namespace :api do
        namespace :v1 do
        end
      end
    RUBY
  end
  color 'Routes updated', GREEN, BACKGROUND_BLACK

  # Git ignore
  ########################################
  color "-----> Updating .gitignore", WHITE, BACKGROUND_BLACK
  append_file '.gitignore', <<~TXT
    # Ignore .env file containing credentials.
    .env*
    # Ignore Mac and Linux file system files
    *.swp
    .DS_Store
  TXT
  color "-----> .gitignore updated", GREEN, BACKGROUND_BLACK

  # Devise install + user
  ########################################
  color "-----> Installing Devise", WHITE, BACKGROUND_BLACK
  generate 'devise:install'
  generate 'devise', 'User'
  color "-----> Devise installed", GREEN, BACKGROUND_BLACK

  # Rack Cors
  ########################################
  color "-----> Installing Rack Cors", WHITE, BACKGROUND_BLACK
  run 'rm config/initializers/cors.rb'
  touch 'config/initializers/cors.rb'
  file 'config/initializers/cors.rb', <<-RUBY
    # Be sure to restart your server when you modify this file.

    # Avoid CORS issues when API is called from the frontend app.
    # Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests.

    # Read more: https://github.com/cyu/rack-cors

    Rails.application.config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'

        resource '*',
          headers: :any,
          methods: %i[get post put patch delete options head],
          expose: %w[Authorization Uid]
      end
    end
  RUBY
  color "-----> Rack Cors installed", GREEN, BACKGROUND_BLACK

  # Rspec install
  ########################################
  color "-----> Installing Rspec", WHITE, BACKGROUND_BLACK
  generate 'rspec:install'
  color "-----> Rspec installed", GREEN, BACKGROUND_BLACK

  # Config Rspec
  ########################################
  ######## FactoryBot helpers and Devise for Integrations test
  ########################################
  color "-----> Configuring Rspec", WHITE, BACKGROUND_BLACK
  inject_into_file 'spec/rails_helper.rb', after: '# config.use_active_record = false' do
    <<~RUBY
      config.include FactoryBot::Syntax::Methods
      config.include Devise::Test::IntegrationHelpers, type: :request
      config.include Warden::Test::Helpers
      config.expect_with :rspec do |c|
        c.syntax = :expect
      end
    RUBY
  end
  color "-----> Rspec configured", GREEN, BACKGROUND_BLACK

  ######## Shoulda Helpers for rspec
  #######################################
  color "-----> Configuring Shoulda Matchers", WHITE, BACKGROUND_BLACK
  append_file 'spec/rails_helper.rb', <<~RUBY
    Shoulda::Matchers.configure do |config|
      config.integrate do |with|
        with.test_framework :rspec
        with.library :rails
      end
    end
  RUBY
  color "-----> Shoulda Matchers configured", GREEN, BACKGROUND_BLACK

  # App controller
  ########################################
  color "-----> Updating Controller", WHITE, BACKGROUND_BLACK
  mkdir 'app/controllers/api'
  mkdir 'app/controllers/api/v1'
  touch 'app/controllers/api/v1/api_controller.rb'
  file 'app/controllers/api/v1/api_controller.rb', <<-RUBY
    class Api::V1::ApiController < ApplicationController

      private

      def current_user
        decoded_token = JWT.decode(
          request.headers['Authorization'].split(' ').last,
          Rails.application.credentials.devise[:jwt_secret_key]).first
        user_id = decoded_token['sub']
        user ||= User.find(user_id.to_s)
      end
    end
  RUBY

  insert_into_file 'app/controllers/application_controller.rb', after: "class ApplicationController < ActionController::API\n" do
    <<~RUBY
      include ActionController::MimeResponds
      respond_to :json
    RUBY
  end

  color "-----> Controller updated", GREEN, BACKGROUND_BLACK

  # migrate
  ########################################
  color "-----> Migrating database", WHITE, BACKGROUND_BLACK
  rails_command 'db:migrate'
  color "-----> Database migrated", GREEN, BACKGROUND_BLACK

  # Environments
  ########################################
  color "-----> Updating environments", WHITE, BACKGROUND_BLACK
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: 'development'
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: 'production'
  color "-----> Environments updated", GREEN, BACKGROUND_BLACK

  # Dotenv
  ########################################
  color "-----> Creating .env file", WHITE, BACKGROUND_BLACK
  run 'touch .env'
  color "-----> .env file created", GREEN, BACKGROUND_BLACK

  # Procfile
  ########################################
  color "-----> Creating Procfile", WHITE, BACKGROUND_BLACK
  run "touch Procfile"
  append_file 'Procfile', "back: bin/rails server --port 3000\nfront: bin/webpack-dev-server"
  color "-----> Procfile created", GREEN, BACKGROUND_BLACK

  # Rubocop
  ########################################
  color "-----> Set Rubocop", WHITE, BACKGROUND_BLACK
  run 'curl -L https://raw.githubusercontent.com/MadzMed/mytemplates/master/.rubocop.yml > .rubocop.yml'
  color "-----> Rubocop set", GREEN, BACKGROUND_BLACK

  # Fix puma config
  ########################################
  color "-----> Fixing puma config", WHITE, BACKGROUND_BLACK
  gsub_file('config/puma.rb', 'pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }', '# pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }')
  color "-----> Puma config fixed", GREEN, BACKGROUND_BLACK

  # Git
  ########################################
  color "-----> Initializing git", WHITE, BACKGROUND_BLACK
  git :init
  git add: '.'
  git commit: "-m ':tada: init rails api'"
  color "-----> Git initialized", GREEN, BACKGROUND_BLACK
end

color "Rails API template applied", GREEN, BACKGROUND_BLACK
