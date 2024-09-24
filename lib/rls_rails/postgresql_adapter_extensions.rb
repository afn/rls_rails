module RLS::PostgreSQLAdapterExtensions
  extend ActiveSupport::Concern

  self.included do |base|
    base.wrap_methods :execute, :query, :select, :exec_delete, :exec_update, :exec_insert
  end

  module ClassMethods
    def wrap_methods *methods
      methods.each do |method|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{method}(...)
            steal_thread_for_rls!
            super
          end
        RUBY
      end
    end
  end

  def initialize(...)
    super
    @rls_enabled = self.class.type_cast_config_to_boolean(
      @config.fetch(:rls_enabled, true)
    )
  end

  def rls_enabled?
    @rls_enabled
  end

  private

  def steal_thread_for_rls!
    @lock.synchronize do
      return if @_inside_steal_thread_for_rls

      @_inside_steal_thread_for_rls = true

      owner_thread = RLS.connection_to_thread[self]
      return if owner_thread.nil? || owner_thread == Thread.current

      # Activate the current thread's state, or an empty state if the current thread isn't within an RLS.with block
      state = RLS.stack.peek || RLS::State.new
      state.activate_for self
    ensure
      @_inside_steal_thread_for_rls = false
    end
  end
end
