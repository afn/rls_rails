class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { primary: :primary, secondary: :secondary, tertiary: :tertiary }
end
