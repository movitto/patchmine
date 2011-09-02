require File.dirname(__FILE__) + '/../test_helper'

class MailingListTest < ActiveSupport::TestCase
  fixtures :mailing_lists, :projects

  def setup
    @project = projects(:projects_001)
  end

  def test_validations
    list = MailingList.new :address => 'foo@bar.com',
                           :project_id => @project.id
    assert list.valid?

    list.address = nil
    assert !list.valid?

    list.address = 'aaaa'
    assert !list.valid?
  end

  # ---------------------------------

  def test_smtp_login
    list = MailingList.new :address => 'foo@bar.com',
                           :project_id => @project.id
    assert_nothing_raised {
      smtp = list.send :smtp_login # private method
    }
    assert smtp.started?
    assert smtp.ssl?
  end

  def test_imap_login
    list = MailingList.new :address => 'foo@bar.com',
                           :project_id => @project.id
    assert_nothing_raised {
      imap = list.send :imap_login # private method
    }
  end

  def test_smtp_domain
    list = MailingList.new :address => 'foo@bar.com',
                           :project_id => @project.id
    list.instance_variable_set(:@smtp_username, 'foo@bar.com')
    assert_equals "bar.com", list.send(:smtp_domain) # private method
  end

  def test_subscribe_address
    list = MailingList.new :address => 'foo@bar.com',
                           :project_id => @project.id
    assert_equal "foo-subscribe@bar.com", list.send(:subscribe_address) # private method
  end

  def test_request_address
    list = MailingList.new :address => 'foo@bar.com',
                           :project_id => @project.id
    assert_equal "foo-request@bar.com", list.send(:request_address) # private method
  end

  def test_message_for
    date = Time.now
    fdate = date.strftime("%a, %d %b %Y %H:%M:%S +0500")

    list = MailingList.new :address => 'foo@bar.com',
                           :project_id => @project.id
    list.instance_variable_set(:@smtp_username, 'foo@bar.com')
    assert_equal "From: foo@bar.com\nTo: baz@var.com\nSubject:test-subject\nDate:#{fdate}\ntest-body\n",
                  list.send(:message_for, {:address => 'baz@var.com',
                                           :subject => 'test-subject',
                                           :date    => date,
                                           :body    => 'test-body' }) # private method
  end

  # ---------------------------------

  def test_subscribe_to_list
    list = MailingList.new :address => 'baz@mo.com',
                           :project_id => @project.id
    msg = list.message_for :address => 'baz-subscribe@mo.com', :subject => 'subscribe'

    list.smtp = mocked_smtp 
    list.smtp.expects(:send_message).with(msg, 'foo@bar.com', 'baz-subscribe@mo.com')
    list.smtp.expects(:finish) 
    assert_nothing_raised { list.subscribe }
  end

  def test_sync_list_handles_confirmation_email
    list = MailingList.new :address => 'baz@mo.com',
                           :project_id => @project.id
    list.imap = mock_imap
    list.smtp = mock_smtp
    imap_envelop = mock_imap_envelope

    subject = "confirm list-subscription"
    msg = list.message_for :address => 'baz-request@mo.com',
                           :subject => subject, :body    => subject

    imap.expects(:fetch).with(['NOT', 'SEEN']).returns imap_envelope
    imap_envelope.expects(:subject).returns(subject).times(2)
    smtp.expects(:send_message).with(msg, 'foo@bar.com', 'baz-request@mo.com')
    smtp.expects(:finish)

    assert_nothing_raised { list.sync }
  end

  def test_sync_list_handles_patches_email
    list = MailingList.new :address => 'baz@mo.com',
                           :project_id => @project.id
    list.imap = mock_imap

    subject = "[PATCH conductor] #1 resolves issue 1"

    imap.expects(:fetch).with(['NOT', 'SEEN']).returns imap_envelope
    imap_envelope.expects(:subject).returns(subject).times(3)
    imap_envelope.expects(:headers).returns({'Message-Id' => "test_headers_1"})
    imap_envelope.expects(:body).returns("patch content")

    assert_nothing_raised { list.sync }
    assert !Patch.find(:first, :conditions => {:issue_id => 1,
                                               :mailing_list_id => list.id,
                                               :message_id => "test_headers_1",
                                               :subject    => "resolves issue 1",
                                               :content    => "patch content"}).nil? 

    assert_equal "In Progress", Issue.find(1).status.name
  end

  def test_sync_list_handles_chained_patches_email
    list = MailingList.new :address => 'baz@mo.com',
                           :project_id => @project.id
    list.imap = mock_imap

    first_patch = Patch.new :issue_id => 1,
                            :mailing_list_id => list.id,
                            :message_id => 'test_headers_1',
                            :subject => 'resolves issue 1',
                            :content => 'patch content'
    first_patch.save!

    subject = "[PATCH conductor] second patch in series"

    imap.expects(:fetch).with(['NOT', 'SEEN']).returns imap_envelope
    imap_envelope.expects(:subject).returns(subject).times(4)
    imap_envelope.expects(:headers).returns({'Message-Id'  => "test_headers_2",
                                             'In-Reply-To' => 'test_headers_1'}).times(2)
    imap_envelope.expects(:body).returns("second patch content")

    assert_nothing_raised { list.sync }
    assert !Patch.find(:first, :conditions => {:issue_id => 1,
                                               :mailing_list_id => list.id,
                                               :patch_id   => first_patch.id,
                                               :message_id => "test_headers_1",
                                               :subject    => "resolves issue 1",
                                               :content    => "second patch content"}).nil? 

    assert_equal "In Progress", Issue.find(1).status.name
  end

  def test_sync_list_handles_patch_comments_email
    list = MailingList.new :address => 'baz@mo.com',
                           :project_id => @project.id
    list.imap = mock_imap

    patch = Patch.new :issue_id => 1,
                      :mailing_list_id => list.id,
                      :message_id => 'test_headers_1',
                      :subject => 'resolves issue 1',
                      :content => 'patch content'

    patch.save!

    subject = "RE: [PATCH conductor] #1 resolves issue 1"

    imap.expects(:fetch).with(['NOT', 'SEEN']).returns imap_envelope
    imap_envelope.expects(:subject).returns(subject).times(5)
    imap_envelope.expects(:headers).returns({'Message-Id'  => "test_headers_2",
                                             'In-Reply-To' => 'test_headers_1'}).times(2)
    imap_envelope.expects(:body).returns("some comments")

    assert_nothing_raised { list.sync }
    assert !PatchComment.find(:first, :conditions => {:patch_id   => patch.id,
                                                      :message_id => "test_headers_2",
                                                      :content    => "patch comments"}).nil? 

    assert_equal "Feedback", Issue.find(1).status.name
  end

  def test_sync_list_handles_patch_ack_email
    list = MailingList.new :address => 'baz@mo.com',
                           :project_id => @project.id
    list.imap = mock_imap

    patch = Patch.new :issue_id => 1,
                      :mailing_list_id => list.id,
                      :message_id => 'test_headers_1',
                      :subject => 'resolves issue 1',
                      :content => 'patch content'

    patch.save!

    subject = "RE: [PATCH conductor] #1 resolves issue 1"

    imap.expects(:fetch).with(['NOT', 'SEEN']).returns imap_envelope
    imap_envelope.expects(:subject).returns(subject).times(5)
    imap_envelope.expects(:headers).returns({'Message-Id'  => "test_headers_2",
                                             'In-Reply-To' => 'test_headers_1'}).times(2)
    imap_envelope.expects(:body).returns("ACK")

    assert_nothing_raised { list.sync }
    assert !PatchComment.find(:first, :conditions => {:patch_id   => patch.id,
                                                      :message_id => "test_headers_2",
                                                      :content    => "ACK"}).nil? 

    assert_equal "Resolved", Issue.find(1).status.name
  end

  def test_sync_list_handles_patch_nack_email
    list = MailingList.new :address => 'baz@mo.com',
                           :project_id => @project.id
    list.imap = mock_imap

    patch = Patch.new :issue_id => 1,
                      :mailing_list_id => list.id,
                      :message_id => 'test_headers_1',
                      :subject => 'resolves issue 1',
                      :content => 'patch content'

    patch.save!

    subject = "RE: [PATCH conductor] #1 resolves issue 1"

    imap.expects(:fetch).with(['NOT', 'SEEN']).returns imap_envelope
    imap_envelope.expects(:subject).returns(subject).times(5)
    imap_envelope.expects(:headers).returns({'Message-Id'  => "test_headers_2",
                                             'In-Reply-To' => 'test_headers_1'}).times(2)
    imap_envelope.expects(:body).returns("ACK")

    assert_nothing_raised { list.sync }
    assert !PatchComment.find(:first, :conditions => {:patch_id   => patch.id,
                                                      :message_id => "test_headers_2",
                                                      :content    => "NACK"}).nil? 

    assert_equal "Closed", Issue.find(1).status.name
  end

  private

  def mock_smtp
    smtp = mock('smtp')
    smtp.expects :enable_ssl
    smtp.expects(:start).with("bar.com", "foo@bar.com", "foobar")
    smtp
  end

  def mock_imap
    imap = mock('imap')
    imap.expects(:authenticate).with('LOGIN', 'foo@bari.com', 'foobari')
    imap.expects(:select).with('INBOX')
    imap
  end

  def mock_imap_envelope
    envelope = mock('envelope')
    envelope.expects(:from).returns([envelope])
    envelope.expects(:name).returns("me")
    envelope
  end

end
