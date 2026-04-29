class LegacyRedirect < ApplicationRecord
  belongs_to :package_version
  belongs_to :entity_version

  validates :old_path, presence: true, uniqueness: { scope: :package_version_id }
end
