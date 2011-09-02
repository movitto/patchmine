require File.dirname(__FILE__) + '/../test_helper'

class PatchCommentTest < ActiveSupport::TestCase
  fixtures :patch_comments

  def test_validations
    patch_comment = PatchComment.new :issue_id => 1, :message_id => 1
    assert patch_comment.valid?

    patch_comment.patch_id = nil
    assert !list.valid?
    patch_comment.patch_id = 1

    patch_comment.message_id = nil
    assert !patch_comment.valid?
  end
end
