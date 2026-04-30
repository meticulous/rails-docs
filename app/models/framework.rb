class Framework < ApplicationRecord
  # Frameworks whose Ruby top-level module name doesn't match
  # `display_name.delete(" ")`. Most frameworks are happily named
  # "Active Record" → "ActiveRecord", but Railties is "Rails", and a
  # handful of edge cases need explicit mapping.
  TOP_MODULE_OVERRIDES = {
    "Railties" => "Rails"
  }.freeze

  belongs_to :source

  has_many :entity_identities, dependent: :nullify
  has_many :entity_versions, dependent: :nullify

  validates :slug, presence: true, uniqueness: { scope: :source_id }
  validates :display_name, presence: true

  # The fully qualified name of the top-level module that represents this
  # framework — e.g. "ActiveRecord" for the Active Record framework. Used
  # to link a framework card on the version overview to its module page.
  def top_module_fqn
    TOP_MODULE_OVERRIDES[display_name] || display_name.delete(" ")
  end
end
