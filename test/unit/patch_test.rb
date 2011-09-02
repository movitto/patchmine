require File.dirname(__FILE__) + '/../test_helper'

class PatchTest < ActiveSupport::TestCase
  fixtures :patches

  def test_validations
    patch = Patch.new :issue_id => 1, :message_id => 1
    assert patch.valid?

    patch.patch_id = nil
    assert !list.valid?
    patch.patch_id = 1

    patch.message_id = nil
    assert !patch.valid?
  end
end
