module RLS
  module SchemaDumper
    LIST_POLICIES_SQL = <<~SQL.freeze
      SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
      FROM pg_policies
      ORDER BY schemaname, tablename, policyname;
    SQL

    LIST_RLS_ENABLED_TABLES_SQL = <<~SQL.freeze
      SELECT nspname AS schemaname, relname AS tablename, relforcerowsecurity AS force
      FROM pg_class
      INNER JOIN pg_namespace nsp ON nsp.oid = relnamespace
      WHERE relrowsecurity
      ORDER BY nspname, relname;
    SQL

    def tables(stream)
      super
      rls_statements(stream)
    end

    def rls_statements(stream)
      # Enable RLS
      list_rls_enabled_tables.each do |schema, table, force|
        stream.puts <<-DEFINITION
  enable_rls #{quoted_table_name(schema, table)}, force: #{force.inspect}
        DEFINITION
      end

      # Enumerate policies
      list_policies.each do |(schema, table), policies|
        stream.puts <<-DEFINITION
  create_policy #{quoted_table_name(schema, table)}, sql_definition: <<-\SQL
#{policy_definition(policies).indent(4)}
  SQL
        DEFINITION
      end
    end

    private

    def quoted_table_name schema, table
      schema = nil if schema == @connection.current_schema
      [schema, table].compact.join('.').inspect
    end

    def policy_definition policies
      policies.map do |policy|
        roles = PG::TextDecoder::Array.new.decode(policy['roles'])

        base_policy = <<~POLICY.strip
          CREATE POLICY #{@connection.quote_table_name(policy['policyname'])} ON #{quoted_table_name(policy['schemaname'], policy['tablename'])}
          AS #{policy['permissive']}
          FOR #{policy['cmd']}
          TO #{roles.map{ |role| @connection.quote_table_name(role) }.join(', ')}
        POLICY

        using_expression = "USING (#{policy['qual']})" if policy['qual'].present?
        with_expression = "WITH CHECK (#{policy['with_check']})" if policy['with_check'].present?

        [base_policy, using_expression, with_expression].compact.join("\n") + ';'
      end.join("\n\n")
    end

    def list_policies
      @connection.execute(LIST_POLICIES_SQL).group_by { |row| [row['schemaname'], row['tablename']] }
    end

    def list_rls_enabled_tables
      @connection.execute(LIST_RLS_ENABLED_TABLES_SQL).map { |row| [row['schemaname'], row['tablename'], row['force']] }
    end
  end
end
