module RLS::AbstractAdapterExtensions
  extend ActiveSupport::Concern

  def rls_enabled?
    false
  end
end
