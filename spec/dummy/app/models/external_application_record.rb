class ExternalApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :external }
end
