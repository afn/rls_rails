require 'concurrent'

class RLS::ThreadLocalStack
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
    @thread_map.delete(thread_map_key) if s.empty?
    result
  end

  def peek
    stack&.last
  end

  def active?
    @thread_map.key?(thread_map_key)
  end

  private

  def thread_map_key
    Thread.current
  end

  def stack(initialize: false)
    @stack = if initialize
               @thread_map[thread_map_key] ||= []
             else
               @thread_map[thread_map_key]
             end
  end
end
