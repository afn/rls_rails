require "rails"

module RLS
  def self.configure
    @configuration ||= Railtie.config.rls_rails
    yield @configuration if block_given?
  end

  class Railtie < ::Rails::Railtie
    config.rls_rails = ActiveSupport::OrderedOptions.new
    config.rls_rails.policy_dir = 'db/policies'
    config.rls_rails.tenant_class = nil
    config.rls_rails.user_class = nil
    config.rls_rails.tenant_fk = :tenant_id
    config.rls_rails.verbose = false

    initializer "rls_rails.load" do
      ActiveSupport.on_load :active_record do
        ActiveRecord::Migration.include RLS::Statements
        ActiveRecord::SchemaDumper.prepend RLS::SchemaDumper
        ActiveRecord::ConnectionAdapters::AbstractAdapter.set_callback(:checkout, :after) do |connection|
          RLS.checked_out(connection)
        end
        ActiveRecord::ConnectionAdapters::AbstractAdapter.include RLS::AbstractAdapterExtensions
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include RLS::PostgreSQLAdapterExtensions
      end
    end

    rake_tasks do
      load 'rls_rails/tasks/init.rake'
      load 'rls_rails/tasks/recreate.rake'
    end
  end
end
