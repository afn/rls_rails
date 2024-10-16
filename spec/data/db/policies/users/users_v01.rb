RLS.policies_for :users do
  policy :my_policy do
    using <<-SQL
      (id = current_user_id())
    SQL
  end
end
