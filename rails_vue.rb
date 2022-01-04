run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# GEMFILE
########################################
inject_into_file 'Gemfile', before: 'group :development, :test do' do
  <<~RUBY
    gem 'devise'
    gem 'foreman'
    gem 'autoprefixer-rails'
    gem 'font-awesome-sass'
    gem 'simple_form'
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

gsub_file('Gemfile', /# gem 'redis'/, "gem 'redis'")

# Assets
########################################
run 'rm -rf app/assets/stylesheets'
run 'rm -rf vendor'
run 'curl -L https://github.com/lewagon/stylesheets/archive/master.zip > stylesheets.zip'
run 'unzip stylesheets.zip -d app/assets && rm stylesheets.zip && mv app/assets/rails-stylesheets-master app/assets/stylesheets'
touch 'app/assets/stylesheets/config/index.scss'
inject_into_file 'app/assets/stylesheets/config/index.scss' do
  @import "fonts";
  @import "colors";
  @import "bootstrap_variables";
end

# Dev environment
########################################
gsub_file('config/environments/development.rb', /config\.assets\.debug.*/, 'config.assets.debug = false')

# Layout
########################################
if Rails.version < "6"
  scripts = <<~HTML
    <%= stylesheet_pack_tag 'application', 'data-turbolinks-track': 'reload' %>
    <%= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload', defer: true %>
  HTML
  gsub_file('app/views/layouts/application.html.erb', "<%= javascript_include_tag 'application', 'data-turbolinks-track': 'reload' %>", scripts)
end

gsub_file('app/views/layouts/application.html.erb', "<%= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload' %>", "<%= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload', defer: true %>")

style = <<~HTML
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
  <%= stylesheet_link_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>
HTML
gsub_file('app/views/layouts/application.html.erb', "<%= stylesheet_link_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>", style)

# Flashes
########################################
file 'app/views/shared/_flashes.html.erb', <<~HTML
  <% if notice %>
    <div class="alert alert-info alert-dismissible fade show m-1" role="alert">
      <%= notice %>
      <button type="button" class="close" data-dismiss="alert" aria-label="Close">
        <span aria-hidden="true">&times;</span>
      </button>
    </div>
  <% end %>
  <% if alert %>
    <div class="alert alert-warning alert-dismissible fade show m-1" role="alert">
      <%= alert %>
      <button type="button" class="close" data-dismiss="alert" aria-label="Close">
        <span aria-hidden="true">&times;</span>
      </button>
    </div>
  <% end %>
HTML

run 'curl -L https://github.com/lewagon/awesome-navbars/raw/master/templates/_navbar_wagon.html.erb > app/views/shared/_navbar.html.erb'

inject_into_file 'app/views/layouts/application.html.erb', after: '<body>' do
  <<-HTML
    <%= render 'shared/navbar' %>
    <%= render 'shared/flashes' %>
  HTML
end

# README
########################################
markdown_file_content = <<-MARKDOWN
  Welcome to the rails vue template
MARKDOWN
file 'README.md', markdown_file_content, force: true

# Generators
########################################
generators = <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :rspec, fixture: false
    generate.factory_bot dir: 'spec/factories/'
    generate.factory_bot suffix: "factory"
  end
RUBY

environment generators

########################################
# AFTER BUNDLE
########################################
after_bundle do
  # Generators: db + simple form + pages controller
  ########################################
  rails_command 'db:drop db:create db:migrate'
  generate(:controller, 'pages', 'home', '--skip-routes', '--no-test-framework')

  run 'rm app/views/pages/home.html.erb'
  run 'touch app/views/pages/home.html.erb'
  append_file 'app/views/pages/home.html.erb', <<~HTML
    <div id="hello">
      {{message}}
      <App></App>
      }
    </div>
  HTML

  generate('simple_form:install', '--bootstrap')

  # Routes
  ########################################
  route "root to: 'pages#home'"

  # Git ignore
  ########################################
  append_file '.gitignore', <<~TXT
    # Ignore .env file containing credentials.
    .env*
    # Ignore Mac and Linux file system files
    *.swp
    .DS_Store
  TXT

  # Devise install + user
  ########################################
  generate('devise:install')
  generate('devise', 'User')

  # Rspec Install
  ########################################
  generate('rspec:install')

  # Config Rspec
  ########################################
  ######## FactoryBot helpers and Devise for Integrations test
  ########################################

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

  ######## Shoulda Helpers for rspec
  #######################################
  append_file 'spec/rails_helper.rb', <<~RUBY
    Shoulda::Matchers.configure do |config|
      config.integrate do |with|
        with.test_framework :rspec
        with.library :rails
      end
    end
  RUBY

  # App controller
  ########################################
  run 'rm app/controllers/application_controller.rb'
  file 'app/controllers/application_controller.rb', <<~RUBY
    class ApplicationController < ActionController::Base
    #{"protect_from_forgery with: :exception\n" if Rails.version < "5.2"}  before_action :authenticate_user!
    end
  RUBY

  # migrate + devise views
  ########################################
  rails_command 'db:migrate'
  generate('devise:views')

  # Pages Controller
  ########################################
  run 'rm app/controllers/pages_controller.rb'
  file 'app/controllers/pages_controller.rb', <<~RUBY
    class PagesController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :home ]

      def home
      end
    end
  RUBY

  # Environments
  ########################################
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: 'development'
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: 'production'

  # Webpacker / Yarn
  ########################################
  run 'yarn add popper.js jquery bootstrap vue-turbolinks'
  append_file 'app/javascript/packs/application.js', <<~JS
    import App from '../app.vue'
    import TurbolinksAdapter from 'vue-turbolinks';
    import Vue from 'vue/dist/vue.esm'

    // External imports
    import "bootstrap";

    // Internal imports, e.g:
    // import { initSelect2 } from '../components/init_select2';

    document.addEventListener('turbolinks:load', () => {
      const app = new Vue({
        el: '',
        data: () => {
          return {
            message: "Can you say hello?"
          }
        },
        components: { App }
      })
    });
  JS

  run 'mkdir app/config/webpack/loaders'
  run 'touch app/config/webpack/loaders/sass.js'
  inject_into_file 'app/config/webpack/sass.js' do
    const { config } = require('@rails/webpacker')

    module.exports = {
      test: /\.sass$/,
      use: [
        'vue-style-loader',
        {
          loader: 'css-loader',
          options: {
            sourceMap: true,
            importLoaders: 2
          }
        },
        {
          loader: 'sass-loader',
          options: {
            sourceMap: true,
            implementation: require('sass'),
            additionalData: `@import "app/assets/stylesheets/config/index.scss"`,
            indentedSyntax: true
          }
        }
      ]
    }
  end

  run 'touch app/config/webpack/loaders/scss.js'
  inject_into_file 'app/config/webpack/scss.js' do
    const { config } = require('@rails/webpacker')

    module.exports = {
      test: /\.scss$/,
      use: [
        'vue-style-loader',
        {
          loader: 'css-loader',
          options: {
            sourceMap: true,
            importLoaders: 2
          }
        },
        {
          loader: 'postcss-loader',
          options: {
            sourceMap: true
          }
        },
        {
          loader: 'sass-loader',
          options: {
            sourceMap: true,
            implementation: require('sass'),
            additionalData: `@import "app/assets/stylesheets/config/index.scss";`
          }
        }
      ]
    }
  end
  
  run 'touch app/config/webpack/loaders/vue.js'
  inject_into_file 'app/config/webpack/vue.js' do
    module.exports = {
      test: /\.vue(\.erb)?$/,
      use: [{
        loader: 'vue-loader',
      }],
    }
  end

  inject_into_file 'config/webpack/environment.js', before: 'module.exports' do
    <<~JS
      const vue = require('./loaders/vue')
      const sass = require('./loaders/sass')
      const scss = require('./loaders/scss')
      const webpack = require('webpack');
      // Preventing Babel from transpiling NodeModules packages
      environment.loaders.delete('nodeModules');
      // Bootstrap 4 has a dependency over jQuery & Popper.js:
      environment.plugins.prepend('Provide',
        new webpack.ProvidePlugin({
          $: 'jquery',
          jQuery: 'jquery',
          Popper: ['popper.js', 'default']
        })
      );
      environment.plugins.prepend('VueLoaderPlugin', new VueLoaderPlugin())
      environment.loaders.prepend('vue', vue)
      environment.loaders.append('sass', sass)
      environment.loaders.append('scss', scss)
    JS
  end

  run 'touch app/javascript/packs/hello_world.js'
  append_file 'app/javascript/packs/hello_world.js', <<~JS
    import TurbolinksAdapter from 'vue-turbolinks';
    import Vue from 'vue/dist/vue.esm'
    import App from '../app.vue'

    Vue.use(TurbolinksAdapter);

    document.addEventListener('turbolinks:load', () => {
      const app = new Vue({
        el: '#hello',
        data: () => {
          return {
            message: "Can you say hello?"
          }
        },
        components: { App }
      })
    });
  JS

  # Dotenv
  ########################################
  run 'touch .env'

  # Procfile
  ########################################
  run "touch Procfile"
  append_file 'Procfile', "back: bin/rails server --port 3000\nfront: bin/webpack-dev-server"

  # Rubocop
  ########################################
  run 'curl -L https://raw.githubusercontent.com/lewagon/rails-templates/master/.rubocop.yml > .rubocop.yml'

  # Fix puma config
  gsub_file('config/puma.rb', 'pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }', '# pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }')

  # Git
  ########################################
  git add: '.'
  git commit: "-m ':tada: init'"
end
