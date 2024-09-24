require 'rls_rails/concurrency'

class RLS::State
  include RLS::Concurrency

  attr_reader :user, :tenant, :rls_disabled

  def initialize user: nil, tenant: nil, rls_disabled: nil
    @user = user
    @tenant = tenant
    @rls_disabled = rls_disabled
  end

  def activate_for connection
    return unless connection.rls_enabled?

    RLS.connection_to_thread[connection] = current_thread
    connection.execute to_sql(connection)
  end

  private

  def to_sql connection
    setting_scope = connection.transaction_open? ? 'LOCAL' : 'SESSION'
    [
      "SET #{setting_scope} rls.disable = #{connection.quote(rls_disabled ? 'TRUE' : 'FALSE')}",
      "SET #{setting_scope} rls.user_id = #{connection.quote(user&.id.to_s)}",
      "SET #{setting_scope} rls.tenant_id = #{connection.quote(tenant&.id.to_s)}",
    ].join(';')
  end
end
