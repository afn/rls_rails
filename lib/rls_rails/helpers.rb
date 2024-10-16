require 'rls_rails/state'
require 'rls_rails/thread_local_stack'

module RLS
  mattr_reader :stack, default: RLS::ThreadLocalStack.new
  mattr_reader :connection_to_thread, default: Concurrent::Map.new

  LEASE_CONNECTION_METHOD = ActiveRecord.version < '7.2' ? :connection : :lease_connection

  # TODO: trash connection if stack.push, stack.pop, or activate_configuration! raises an error
  def self.with user: nil, tenant: nil, rls_disabled: nil, &block
    state = RLS::State.new(user: user, tenant: tenant, rls_disabled: rls_disabled)
    stack.push state
    activate_configuration! state
    block.call
  ensure
    stack.pop
    activate_configuration!(stack.peek || State.new)
  end

  def self.disabled &block
    with rls_disabled: true, &block
  end

  def self.checked_out connection
    stack.peek&.activate_for(connection)
  end

  def self.unsafe_disable!
    state = RLS::State.new(user: nil, tenant: nil, rls_disabled: true)
    stack.push state
    activate_configuration! state
  end

  # private
  def self.activate_configuration! state
    connections.each do |connection|
      state.activate_for connection
    rescue ActiveRecord::StatementInvalid => e
      case e.cause
      when PG::InFailedSqlTransaction
        # Transaction has been aborted. We can safely ignore the error, since the rls variables
        # were set via SET LOCAL and will be restored after the transaction is rolled back or a
        # previous savepoint is restored.
      else
        raise e
      end
    end
  end

  # private
  def self.connections
    all_connection_pools.map do |pool|
      pool.public_send(LEASE_CONNECTION_METHOD) if pool.active_connection?
    end.compact
  end

  # private
  def self.all_connection_pools
    if ActiveRecord::VERSION::MAJOR < 7 || (ActiveRecord::VERSION::MAJOR == 7 && ActiveRecord::VERSION::MINOR < 1)
      ActiveRecord::Base.connection_handler.connection_pool_list(nil)
    else
      ActiveRecord::Base.connection_handler.connection_pool_list(:all)
    end
  end

  private_class_method :activate_configuration!, :connections, :all_connection_pools
end
