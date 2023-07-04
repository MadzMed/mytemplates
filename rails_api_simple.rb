run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

RED = "1;31"
GREEN = "1;32"
WHITE = "1;37"
BACKGROUND_BLACK = "40"
BACKGROUND_WHITE = "47"
puts GREEN

def color(text, color_code=RED, background_color=BACKGROUND_WHITE, flash=false)
  text_flash = flash ? "\e[5m" : ""
  puts text_flash + "\e[#{background_color}m\e[#{color_code}m#{text}\e[0m"
end

color "Starting Rails API"

# GEMFILE
########################################
color "Updating Gemfile", WHITE, BACKGROUND_BLACK
gsub_file 'Gemfile', /# gem "rack-cors"/, "gem 'rack-cors'"
inject_into_file 'Gemfile', before: 'group :development, :test do' do
  <<~RUBY
  # Use Devise for authentication
  gem 'devise'
  gem "devise-jwt"
  RUBY
end
color "Gem devise, rack cors, and foreman", WHITE, BACKGROUND_BLACK

inject_into_file 'Gemfile', after: "group :development, :test do" do
  <<~RUBY
  \s\sgem 'rspec'
  \s\sgem 'rspec-rails'
  \s\sgem 'shoulda-matchers'
  \s\sgem 'factory_bot_rails'
  \s\sgem 'dotenv-rails'
  RUBY
end
color "Gem rspec, shoulda-matchers, factory_bot_rails, pry-byebug, pry-rails, dotenv-rails", WHITE, BACKGROUND_BLACK
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
  \s\s\s\sconfig.generators do |generate|
    \s\s\s\sgenerate.test_framework :rspec, fixture: false
    \s\s\s\sgenerate.factory_bot dir: 'spec/factories/'
    \s\s\s\sgenerate.factory_bot suffix: "factory"
  \s\s\s\send
RUBY
insert_into_file 'config/application.rb', generators, after: "config.load_defaults 7.0\n"
color "Updating application.rb", GREEN, BACKGROUND_BLACK

# AFTER BUNDLE
########################################
color 'Running bundle install', WHITE, BACKGROUND_BLACK

after_bundle do
  color 'Bundle install complete', GREEN, BACKGROUND_BLACK

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

  # Rack Cors
  ########################################
  color "-----> Installing Rack Cors", WHITE, BACKGROUND_BLACK
  cors = <<~RUBY
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins '*'

      resource '*',
        headers: :any,
        expose: %w[Authorization Uid],
        methods: [:get, :post, :put, :patch, :delete, :options, :head]
    end
  end
  RUBY
  insert_into_file 'config/initializers/cors.rb', cors, after: "# end\n"

  # Rubocop
  #########################################
  color "-----> Set Rubocop", WHITE, BACKGROUND_BLACK
  run 'curl -L https://raw.githubusercontent.com/MadzMed/mytemplates/master/.rubocop.yml > .rubocop.yml'
  color "-----> Rubocop set", GREEN, BACKGROUND_BLACK

  # App controller
  ########################################
  color "-----> Updating Controller", WHITE, BACKGROUND_BLACK
  run 'mkdir app/controllers/api'
  run 'mkdir app/controllers/api/v1'
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

  # Fix puma config
  ########################################
  color "-----> Fixing puma config", WHITE, BACKGROUND_BLACK
  gsub_file('config/puma.rb', 'pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }', '# pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }')
  color "-----> Puma config fixed", GREEN, BACKGROUND_BLACK

  # Devise install + user
  ########################################
  color "-----> Installing Devise", WHITE, BACKGROUND_BLACK
  generate 'devise:install'
  generate :devise, 'User'
  color "-----> Devise installed", GREEN, BACKGROUND_BLACK

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

  # add data to devise user migration
  ########################################
  color "-----> Adding data to devise user migration", WHITE, BACKGROUND_BLACK
  migration_file = Dir.entries('db/migrate/').select { |file| file.include?('devise_create_users') }.first
  insert_into_file("db/migrate/#{migration_file}", before: '      ## Database authenticatable') do
    <<~RUBY
    ## Custom data for devise
    \s\s\s\s\s\st.string :username
    \s\s\s\s\s\st.string :phone_number

    RUBY
  end

  insert_into_file("db/migrate/#{migration_file}", before: '    add_index :users, :email') do
    <<~RUBY
    \s\s\s\sadd_index :users, :username,             unique: true
    RUBY
  end

  color "-----> Data added to devise user migration", GREEN, BACKGROUND_BLACK


  # create jwt denylist
  ########################################
  color "----> Creating jwt denylist", WHITE, BACKGROUND_BLACK
  generate 'model JwtDenylist jti:string:index exp:datetime'
  jwt_migration_file = Dir.entries('db/migrate/').select { |file| file.include?('create_jwt_denylists') }.first
  gsub_file "db/migrate/#{jwt_migration_file}", 'create_table :jwt_denylists do |t|', 'create_table :jwt_denylist, do |t|'
  File.rename "db/migrate/#{jwt_migration_file}", "db/migrate/#{jwt_migration_file.gsub('create_jwt_denylists', 'create_jwt_denylist')}"
  color "----> Jwt denylist created", GREEN, BACKGROUND_BLACK

  # model user
  ########################################
  color "-----> Updating model user with jwt devise", WHITE, BACKGROUND_BLACK
  gsub_file 'app/models/user.rb', 'devise :database_authenticatable, :registerable,', 'devise :database_authenticatable, :registerable, :jwt_authenticatable,'
  insert_into_file 'app/models/user.rb', after: "validatable" do
    <<~RUBY
    , jwt_revocation_strategy: JwtDenylist
    RUBY
  end
  color "-----> Model user updated", GREEN, BACKGROUND_BLACK

  # migrate
  ########################################
  color "-----> Migrating database", WHITE, BACKGROUND_BLACK
  rails_command 'db:drop db:create db:migrate'
  color "-----> Database migrated", GREEN, BACKGROUND_BLACK

  # Git
  ########################################
  color "-----> Initializing git", WHITE, BACKGROUND_BLACK
  git :init
  git add: '.'
  git commit: "-m ':tada: init rails api'"
  color "-----> Git initialized", GREEN, BACKGROUND_BLACK

  color "Rails API template applied", GREEN, BACKGROUND_BLACK
  color "Happy coding!", GREEN, BACKGROUND_BLACK, true
end

