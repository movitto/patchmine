require 'net/imap'
require 'net/smtp'

# FIXME this should really go in a better place
PATCHMINE_MAIL_CONFIG_FILE = "#{RAILS_ROOT}/vendor/plugins/redmine_patch_mine/config/mail.yml"
PATCHMINE_MAIL_CONFIG = YAML.load_file(PATCHMINE_MAIL_CONFIG_FILE)[RAILS_ENV]

# Handles mailing list operations.
# TODO currently works w/ mailman, would be good to support other list managers
class MailingList < ActiveRecord::Base
  unloadable

  validates_presence_of :address

  validates_format_of :address,
      :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i,
       :message => 'list address must be email'

  belongs_to :project

  validates_presence_of :project_id

  has_many :patches

  # handles to the mail request objects themselves
  attr_accessor :smtp, :imap

  def subscribe
    # send subscription request email
    smtp = smtp_login
    message = message_for :address => subscribe_address, :subject => "subscribe"
    smtp.send_message message, @smtp_username, subscribe_address
    smtp.finish
  end

  # FIXME invoke this method periodically on all mailing lists
  # via the delayed_job plugin or similar
  def sync
    imap = imap_login
    imap.search(["NOT", "SEEN"]).each do |message_id|
       envelope = imap.fetch(message_id, "ENVELOPE")[0].attr["ENVELOPE"]
       puts "#{envelope.from[0].name}: \t#{envelope.subject}"

       # TODO right now we are hardcoding the regex's which are used in matching
       #      and extracting data out of the incoming mail, at some point this
       #      should be customizable by the end user

       # TODO we are assuming that all messages matching the criteria retrieved
       #      from this imap account belong to this mailing list

       # handle subscription confirmation
       if envelope.subject =~ /^\s*confirm\s*([a-f0-9]*)\s*$/
         puts "confirm subscription #{$1}"
         smtp = smtp_login
         message = message_for :address => request_address, :subject => "confirm #{$1}", :body => "confirm #{$1}"
         smtp.send_message message, @smtp_username, request_address
         smtp.finish

       # handle received patches
       elsif envelope.subject =~ /^\s*\[PATCH[^\]]*\]\s*#([0-9]*).*$/i
         puts "Received patch #{$2}"
         puts "  Associating w/ issue ##{$1}"

         issue = Issue.find $1
         patch = Patch.new :issue_id   => issue.id,
                           :mailing_list_id => self.id,
                           :message_id => envelope.headers['Message-Id'],
                           :subject    => $2,
                           :content    => envelope.body
         patch.save!

         issue.status = IssueStatus.find_by_name("In Progress")
         issue.save!

       # handle chained patches (first one may be the only one w/ the issue id)
       elsif envelope.subject =~ /^\s*\[PATCH[^\]]*\].*$/i
         # TODO handle multiple levels of patch replies
         parent_message_id = envelope.headers['In-Reply-To']
         parent_patch = Patch.find_by_message_id(parent_message_id)

         puts "Received chained patch #{$2}"
         puts "  Associating w/ issue ##{parent_patch.issue_id} (parent patch ##{parent_patch.id})"

         patch = Patch.new :issue_id  => parent_patch.issue_id,
                           :mailing_list_id => self.id,
                           :patch_id   => parent_patch.id,
                           :message_id => envelope.headers['Message-Id'],
                           :subject    => $2,
                           :content    => envelope.body

         patch.save!

         issue.status = IssueStatus.find_by_name("In Progress")
         issue.save!

       # handle received patch comments
       elsif envelope.subject =~ /^\s*RE:\s*\[PATCH[^\]]*\]\s*#([0-9]*).*$/i
         # TODO handle multiple levels of replies
         parent_message_id = envelope.headers['In-Reply-To']
         parent_patch = Patch.find_by_message_id(parent_message_id)

         puts "Received response to patch #{$2}"
         puts "  Associating w/ patch ##{parent_patch.id}"

         patch_comment = PatchComment.new :patch_id   => parent_patch.id,
                                          :message_id => envelope.headers['Message-Id'],
                                          :content    => envelope.body

         status = if envelope.body =~ /.*NACK.*/i
                    IssueStatus.find_by_name("Rejected")
                  elsif envelope.body =~ /.*ACK.*/i
                    IssueStatus.find_by_name("Resolved")
                  else
                    IssueStatus.find_by_name("Feedback")
                  end

         issue.status = status
         issue.save!
       end


    end
  end

  private

  # Helper to log into imap mail account
  def imap_login
    # grab email configuration from config file
    @imap_host     = PATCHMINE_MAIL_CONFIG['imap_host']
    @imap_port     = PATCHMINE_MAIL_CONFIG['imap_port']
    @imap_username = PATCHMINE_MAIL_CONFIG['imap_username']
    @imap_password = PATCHMINE_MAIL_CONFIG['imap_password']
    use_ssl, cert, verify = true, nil, false

    imap = Net::IMAP.new(@imap_host, @imap_port, use_ssl, cert, verify) if imap.nil?
    imap.authenticate('LOGIN', @imap_username, @imap_password)
    imap.select('INBOX')
    return imap
  end

  # Helper to log into smtp mail account
  #  (normally we'd use actionmailer but this is a bit tricky
  #   since this needs to be manifested in a redmine plugin)
  def smtp_login
    @smtp_host     = PATCHMINE_MAIL_CONFIG['smtp_host']
    @smtp_port     = PATCHMINE_MAIL_CONFIG['smtp_port']
    @smtp_username = PATCHMINE_MAIL_CONFIG['smtp_username']
    @smtp_password = PATCHMINE_MAIL_CONFIG['smtp_password']

    smtp = Net::SMTP.new(@smtp_host, @smtp_port) if smtp.nil?
    smtp.enable_ssl
    smtp.start(smtp_domain, @smtp_username, @smtp_password)
    smtp
  end

  # Helper to retrieve smtp domain
  def smtp_domain
    @smtp_username.split('@').last
  end

  # Helper to retrieve subscribe address
  def subscribe_address
    address.split('@').join("-subscribe@")
  end

  # Helper to retrieve request address
  def request_address
    address.split('@').join("-request@")
  end

  # Helper to generate message for specified address
  def message_for(params)
    date = params.has_key?(:date) ? params[:date] : Time.now
    message = <<END_OF_MESSAGE
From: #{@smtp_username}
To: #{params[:address]}
Subject: #{params[:subject]}
Date: #{date.strftime("%a, %d %b %Y %H:%M:%S +0500")}
#{params[:body]}
END_OF_MESSAGE
  end


end
