require 'net/imap'
require 'net/smtp'

# FIXME this should really go in a better place
PATCHMINE_MAIL_CONFIG_FILE = "#{RAILS_ROOT}/vendor/plugins/redmine_patch_mine/config/mail.yml"
PATCHMINE_MAIL_CONFIG = YAML.load_file(PATCHMINE_MAIL_CONFIG_FILE)[RAILS_ENV]

class MailingList < ActiveRecord::Base
  unloadable

  validates_format_of :address,
      :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i,
       :message => 'list address must be email'


  def subscribe
    # send subscription request email
    smtp = smtp_login
    message = message_for :address => subscribe_address, :subject => "subscribe"
    smtp.send_message message, @smtp_username, subscribe_address
    smtp.finish
  end

  # FIXME invoke this method periodically on all mailing lists
  # via the delayed_job plugin or similar
  def update
    imap = imap_login
    imap.search(["NOT", "SEEN"]).each do |message_id|
       envelope = imap.fetch(message_id, "ENVELOPE")[0].attr["ENVELOPE"]
       puts "#{envelope.from[0].name}: \t#{envelope.subject}"

       # handle subscription confirmation
       if envelope.subject =~ /^\s*confirm\s*([a-f0-9]*)\s*$/
         puts "confirm subscription #{$1}"
         smtp = smtp_login
         message = message_for :address => request_address, :subject => "confirm #{$1}", :body => "confirm #{$1}"
         smtp.send_message message, @smtp_username, request_address
         smtp.finish
       end

       # TODO handle received patches
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

    imap = Net::IMAP.new(@imap_host, @imap_port, use_ssl, cert, verify)
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

    smtp = Net::SMTP.new(@smtp_host, @smtp_port)
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
    message = <<END_OF_MESSAGE
From: #{@smtp_username}
To: #{params[:address]}
Subject: #{params[:subject]}
Date: #{Time.now.strftime("%a, %d %b %Y %H:%M:%S +0500")}
#{params[:body]}
END_OF_MESSAGE
  end


end
