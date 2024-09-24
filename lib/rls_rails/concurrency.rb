require 'active_support'

module RLS::Concurrency
  def current_thread
    # Rails 7 uses ActiveSupport::IsolatedExecutionState instead of Thread.current
    defined?(ActiveSupport::IsolatedExecutionState) ? ActiveSupport::IsolatedExecutionState.context : Thread.current
  end
end
