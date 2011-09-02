class PatchComment < ActiveRecord::Base
  unloadable

  belongs_to :patch

  validates_presence_of :patch_id
  validates_presence_of :message_id
end
