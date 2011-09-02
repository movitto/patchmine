require File.dirname(__FILE__) + '/../test_helper'

class PatchTest < ActiveSupport::TestCase
  fixtures :patches, :issues

  def test_patch_association
    issue = issues(1)
    issue.patches = [Patch.new(:message_id => "foobar")]
    assert_nothing_raised { issue.save! }
  end
end
