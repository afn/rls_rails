module RLS
  module Statements
    include RLS::Util

    def enable_rls table, force: false
      reversible do |dir|
        dir.up   { do_enable_rls  table, force: force }
        dir.down { do_disable_rls table, force: force }
      end
    end

    def disable_rls table, force: false
      reversible do |dir|
        dir.up   { do_disable_rls table, force: force }
        dir.down { do_enable_rls  table, force: force }
      end
    end

    def create_policy table, version: nil, sql_definition: nil
      if version.present? && sql_definition.present?
        raise(
          ArgumentError,
          "sql_definition and version cannot both be set"
        )
      end

      if version.blank? && sql_definition.blank?
        version = 1
      end

      reversible do |dir|
        dir.up   { do_create_policy table, version: version, sql_definition: sql_definition }
        dir.down { do_drop_policy   table, version: version }
      end
    end

    def drop_policy table, version: nil
      reversible do |dir|
        dir.up   { do_drop_policy   table, version: version }
        dir.down { do_create_policy table, version: version }
      end
    end

    def update_policy table, version: nil, revert_to_version: nil
      RLS.clear_policies!

      reversible do |dir|
        dir.up do
          drop_policies_for table
          do_create_policy(table, version: version || last_version_of(table) + 1)
        end

        dir.down do
          new_version = revert_to_version || last_version_of(table) - 1
          raise ActiveRecord::IrreversibleMigration, 'update_policy: revert_to_version missing!' if revert_to_version.nil? && new_version > 0
          if new_version > 0
            do_drop_policy table, version: version
            do_create_policy table, version: new_version
          else
            do_drop_policy table, version: version
          end
        end
      end
    end

    def change_policy_force table, force
      reversible do |dir|
        dir.up do
          do_set_force_rls table, force
        end
        dir.down do
          do_set_force_rls table, !force
        end
      end
    end

    private

    def drop_policies_for table
      existing_policies = execute("SELECT policyname FROM pg_policies WHERE tablename = '#{table}'").values.flatten
      existing_policies.each do |policy_name|
        perform_query "DROP POLICY #{policy_name} ON #{table};"
      end
    end

    def do_create_policy table, version: nil, sql_definition: nil
      RLS.clear_policies!
      sql_definition ||= begin
        load policy_path(table, version)
        RLS.create_sql(table)
      end

      perform_query sql_definition
    end

    def do_drop_policy table, version: nil
      RLS.clear_policies!
      load policy_path(table, version || last_version_of(table))
      perform_query RLS.drop_sql(table)
    end

    def do_alter_table table, enabled: nil, force: nil
      clauses = []
      clauses << rls_clause(enabled) unless enabled.nil?
      clauses << force_clause(force) unless force.nil?
      return if clauses.empty?

      q = "ALTER TABLE #{table} #{clauses.join(', ')}"
      perform_query q
    end

    def do_enable_rls table, force: false
      do_alter_table table, enabled: true, force: force
    end

    def do_disable_rls table, force: false
      do_alter_table table, enabled: false, force: force
    end

    def do_set_force_rls table, force
      do_alter_table table, force: force
    end

    def rls_clause enabled
      enabled ? 'ENABLE ROW LEVEL SECURITY' : 'DISABLE ROW LEVEL SECURITY'
    end

    def force_clause force
      force ? 'FORCE ROW LEVEL SECURITY' : 'NO FORCE ROW LEVEL SECURITY'
    end

    def perform_query q
      debug_print q
      execute q
    end
  end
end
