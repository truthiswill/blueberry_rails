module BlueberryRails
  class AppBuilder < Rails::AppBuilder
    include BlueberryRails::ActionHelpers

    def readme
      template 'README.md.erb', 'README.md'
    end

    def gitignore
      template 'gitignore_custom.erb', '.gitignore'
    end

    def gemfile
      template 'Gemfile_custom.erb', 'Gemfile'
    end

    def hound_config
      copy_file '../.hound.yml', '.hound.yml'
      copy_file '../.eslintrc', '.eslintrc'
      copy_file '../.rubocop.yml', '.rubocop.yml'

      run 'yarn add -D eslint eslint-config-airbnb-base eslint-config-import'
    end

    def cocoon_config
      run 'yarn add https://github.com/1776/cocoon'
      inject_into_file 'app/javascript/packs/application.js',
                       "import 'cocoon';\n",
                       before: 'import { Application } from "stimulus"'
    end

    def setup_mailer_hosts
      action_mailer_host 'development', "development.#{app_name}.com"
      action_mailer_host 'test', "test.#{app_name}.com"
      action_mailer_host 'staging', "staging.#{app_name}.com"
      action_mailer_host 'integration', "integration.#{app_name}.com"
      action_mailer_host 'production', "#{app_name}.com"
    end

    def use_postgres_config_template
      template 'database.yml.erb', 'config/database.yml', force: true
      template 'database.yml.erb', 'config/database.yml.sample'
    end

    def setup_staging_environment
      run 'cp config/environments/production.rb config/environments/staging.rb'

      replace_in_file 'config/environments/staging.rb',
                      'config.consider_all_requests_local       = false',
                      'config.consider_all_requests_local       = true'
    end

    def setup_integration_environment
      copy_file 'config/environments/production.rb',
                'config/environments/integration.rb'
    end

    def setup_admin
      directory 'admin_controllers', 'app/controllers/admin'
      directory 'admin_views', 'app/views/admin'

      template 'views/layouts/admin.html.slim.erb',
               'app/views/layouts/admin.html.slim'

      inject_into_file 'config/routes.rb',
                       "\n  namespace :admin do\n" \
                       "    root to: 'dashboard#show'\n" \
                       "  end\n\n",
                       before: '  root'
    end

    def create_partials_directory
      directory 'views/application', 'app/views/application', force: true
    end

    def create_application_layout
      remove_file 'app/views/layouts/application.html.erb'
      remove_file 'app/views/layouts/mailer.html.erb'
      remove_file 'app/views/layouts/mailer.text.erb'

      template 'views/layouts/application.html.slim.erb',
               'app/views/layouts/application.html.slim', force: true

      template 'views/layouts/mailer.html.slim.erb',
               'app/views/layouts/mailer.html.slim', force: true

      directory 'helpers', 'app/helpers', force: true

      remove_file 'public/favicon.ico'
      directory 'public/icons', 'public'
    end

    def copy_assets_directory
      remove_file 'app/assets/stylesheets', force: true
      remove_file 'app/assets/javascripts', force: true

      run 'mkdir app/javascript/stylesheets', force: true
      run 'touch app/javascript/packs/application.sass', force: true

      if options[:administration]
        run 'touch app/javascript/packs/admin.js', force: true
        run 'touch app/javascript/packs/admin.sass', force: true
      end
    end

    def copy_initializers
      if options[:translation_engine]
        copy_file 'config/initializers/translation_engine.rb',
                  'config/initializers/translation_engine.rb'
      end
      if options[:bootstrap]
        copy_file 'config/initializers/simple_form_bootstrap.rb',
                  'config/initializers/simple_form_bootstrap.rb', force: true
      end
      copy_file 'config/initializers/airbrake.rb',
                'config/initializers/airbrake.rb'

      copy_file 'config/initializers/plurals.rb',
                'config/initializers/plurals.rb'
    end

    def create_pryrc
      copy_file 'pryrc.rb', '.pryrc'
    end

    def create_procfile
      copy_file 'Procfile', 'Procfile'
    end

    def create_puma_config
      remove_file 'config/puma.rb'
      copy_file 'puma.rb', 'config/puma.rb'
    end

    def create_database
      bundle_command 'exec rails db:create'
    end

    def generate_rspec
      generate 'rspec:install'

      copy_file 'spec/drivers.rb', 'spec/support/drivers.rb'

      inject_into_file 'spec/rails_helper.rb',
                       "\n# Screenshots\n" \
                       "require 'capybara-screenshot/rspec'\n" \
                       "Capybara::Screenshot.autosave_on_failure =\n" \
                       "  (ENV['SCR'] || ENV['AUTO_SCREENSHOT']) == '1'\n",
                       after: "Rails is not loaded until this point!\n"
    end

    def configure_rspec
      copy_file 'spec/spec_helper.rb', 'spec/spec_helper.rb', force: true
    end

    def test_factories_first
      copy_file 'spec/factories_spec.rb', 'spec/models/factories_spec.rb'
    end

    def setup_rspec_support_files
      copy_file 'spec/factory_bot_syntax.rb', 'spec/support/factory_bot.rb'
      copy_file 'spec/database_cleaner_setup.rb', 'spec/support/database_cleaner.rb'
      copy_file 'spec/mail_body_helpers.rb', 'spec/support/mixins/mail_body_helpers.rb'
    end

    def init_guard
      bundle_command 'exec guard init'
    end

    def setup_guard
      config = 'watch(%r{^spec/factories/(.+)\.rb$}) { |m| rspec.spec.call("models/factories") }'
      inject_into_file('Guardfile',
                       "\n\n  #{config}", before: "\nend")
    end

    def raise_on_unpermitted_parameters
      configure_environment 'development',
        'config.action_controller.action_on_unpermitted_parameters = :raise'
    end

    def configure_mailcatcher
      configure_environment 'development',
        'config.action_mailer.delivery_method = :smtp'
      configure_environment 'development',
        "config.action_mailer.smtp_settings = { address: 'localhost', port: 1025 }"
    end

    def configure_generators
      config = <<-RUBY
    config.generators do |generate|
      generate.helper false
      generate.javascript_engine false
      generate.request_specs false
      generate.routing_specs false
      generate.stylesheets false
      generate.test_framework :rspec
      generate.view_specs false
    end

      RUBY

      inject_into_class 'config/application.rb', 'Application', config
    end

    def configure_i18n
      inject_into_file "config/application.rb",
                       "\n    config.i18n.load_path += Dir[Rails.root.join 'config/locales/**/*.{rb,yml}']",
                       before: "\n    # Settings"

      inject_into_file 'config/application.rb',
                       "\n    config.i18n.available_locales = [:cs, :en]\n    config.i18n.default_locale = :cs",
                       before: "\n    # Settings"

      remove_file 'config/locales/en.yml'
      directory 'locales', 'config/locales'
    end

    def configure_i18n_logger
      configure_environment 'development',
                            "# I18n debug\n  I18nLogger = ActiveSupport::" \
                            "Logger.new(Rails.root.join('log/i18n.log'))"
    end

    def configure_circle
      empty_directory '.circleci'
      template 'circle.yml.erb', '.circleci/config.yml'
    end

    def add_ruby_version_file
      current_version = RUBY_VERSION.split('.').map(&:to_i)
      version = if current_version[0] >= 2 && current_version[1] >= 0
                  RUBY_VERSION
                else
                  "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}"
                end
      add_file '.ruby-version', "#{version}\n", force: true
    end

    def install_devise
      generate 'devise:install'
      generate_root_controller_and_route
      if options[:devise_model].present?
        generate 'devise', options[:devise_model]
      end

      if options[:administration]
        generate 'devise', 'administrator'
        replace_in_file 'app/models/administrator.rb',
                        ' :registerable,',
                        ''
      end

      copy_file 'locales/cs/cs.devise.yml', 'config/locales/cs/cs.devise.yml'

      rename_file 'config/locales/devise.en.yml',
                  'config/locales/en/en.devise.yml'
    end

    def configure_simple_form
      if options[:bootstrap]
        generate 'simple_form:install --bootstrap'

        replace_in_file 'config/initializers/simple_form.rb',
                        '# config.label_text = lambda { |label, required, explicit_label| "#{required} #{label}" }',
                        'config.label_text = lambda { |label, required, explicit_label| "#{required} #{label}" }'

      else
        generate 'simple_form:install'
      end
      rename_file 'config/locales/simple_form.en.yml',
                  'config/locales/en/en.simple_form.yml'
    end

    def replace_users_factory
      copy_file 'spec/factories/users.rb',
                'spec/factories/users.rb', force: true
      if options[:administration]
        copy_file 'spec/factories/administrators.rb',
                  'spec/factories/administrators.rb', force: true
      end
    end

    def replace_root_controller_spec
      copy_file 'spec/controllers/root_controller_spec.rb',
                'spec/controllers/root_controller_spec.rb', force: true
    end

    def cache_and_compress
      configure_environment 'production',
        "config.public_file_server.headers = {\n    'Cache-Control' => 'public, max-age=31536000'\n  }"
      configure_environment 'production',
        'config.middleware.insert_before ActionDispatch::Static, Rack::Deflater'
    end

    def setup_gitignore
      [
        'spec/lib',
        'spec/controllers',
        'spec/features',
        'spec/support/matchers',
        'spec/support/mixins',
        'spec/support/shared_examples'
      ].each do |dir|
        run "mkdir -p #{dir}"
        run "touch #{dir}/.keep"
      end
    end

    def init_git
      run 'git init'
    end

    def copy_rake_tasks
      copy_file 'tasks/images.rake', 'lib/tasks/images.rake'
    end

    def copy_custom_errors
      copy_file 'controllers/errors_controller.rb', 'app/controllers/errors_controller.rb'

      config = <<-RUBY
    config.exceptions_app = self.routes

      RUBY

      inject_into_class 'config/application.rb', 'Application', config

      remove_file 'public/404.html', force: true
      remove_file 'public/422.html', force: true
      remove_file 'public/500.html', force: true
    end

    def configure_bin_setup
      copy_file 'setup', 'bin/setup', force: true
    end

    def generate_root_controller_and_route
      generate 'controller', 'root index'
      inject_into_file 'config/routes.rb',
                       "  root to: 'root#index'\n",
                       after: "Rails.application.routes.draw do\n"
    end

    def create_root_page
      generate_root_controller_and_route
    end

    def reviews_app
      template 'app.json.erb', 'app.json'
    end
  end
end
