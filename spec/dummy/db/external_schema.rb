ActiveRecord::Schema.define(:version => 0) do
  create_table :external_things, :force => true do |t|
    t.string :name
  end
end
