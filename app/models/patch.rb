class Patch < ActiveRecord::Base
  unloadable

  belongs_to :issue
  belongs_to :mailing_list
  belongs_to :parent_patch, :foreign_key => :patch_id, :class_name => 'Patch'

  has_many :patch_comments

  validates_presence_of :issue_id
  validates_presence_of :message_id
end
