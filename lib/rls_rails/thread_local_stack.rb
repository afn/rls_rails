require 'concurrent'
require 'rls_rails/concurrency'

class RLS::ThreadLocalStack
  include RLS::Concurrency

  def initialize
    @thread_map = Concurrent::Map.new
  end

  def push(state)
    stack(initialize: true).push state
  end

  def pop
    s = stack
    raise RLS::Error, 'Stack is empty' if s.nil? || s.empty?

    result = s.pop
    @thread_map.delete(current_thread) if s.empty?
    result
  end

  def peek
    stack&.last
  end

  def active?
    @thread_map.key?(current_thread)
  end

  private

  def stack(initialize: false)
    @stack = if initialize
               @thread_map[current_thread] ||= []
             else
               @thread_map[current_thread]
             end
  end
end
