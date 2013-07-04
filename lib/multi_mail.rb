require 'base64'
require 'cgi'
require 'json'
require 'openssl'
require 'iconv' unless RUBY_VERSION >= '1.9'

require 'faraday'
require 'mail'
require 'multimap'
require 'rack'

module MultiMail
  # @see http://rdoc.info/gems/fog/Fog/Errors
  class Error < StandardError; end
  # Raise if an incoming POST request is forged.
  class ForgedRequest < MultiMail::Error; end
  # Raise if an API key is invalid.
  class InvalidAPIKey < MultiMail::Error; end

  # Raise if a message is invalid.
  class InvalidMessage < MultiMail::Error; end
  # Raise if a message has no sender.
  class MissingSender < InvalidMessage; end
  # Raise if a message has no recipients.
  class MissingRecipients < InvalidMessage; end
  # Raise if a message has no subject.
  class MissingSubject < InvalidMessage; end
  # Raise if a message has no body.
  class MissingBody < InvalidMessage; end

  class << self
    # @return [RegExp] a message whose subject matches this pattern will be
    #   considered an autoresponse
    attr_accessor :autoresponse_pattern

    # Configures MultiMail.
    #
    # * `autoresponse_pattern`: a message whose subject matches this pattern will
    #   be considered an autoresponse
    #
    # @example
    #   require 'multi_mail'
    #
    #   MultiMail.setup do |config|
    #     config.autoresponse_pattern = /^Out of Office AutoReply:/i
    #   end
    def setup
      yield self
    end

    # Returns whether a message is an autoresponse.
    #
    # @param [Mail::Message] message a message
    # @return [Boolean] whether a message is an autoresponse
    # @see https://github.com/opennorth/multi_mail/wiki/Detecting-autoresponders
    def autoresponse?(message)
      !!(
        # If any of the following headers are present and have the given value.
        {
          'Delivered-To'          => 'Autoresponder',
          'Precedence'            => 'auto_reply',
          'Return-Path'           => nil, # in most cases, this would signify a bounce
          'X-Autoreply'           => 'yes',
          'X-FC-MachineGenerated' => 'true',
          'X-POST-MessageClass'   => '9; Autoresponder',
          'X-Precedence'          => 'auto_reply',
        }.find do |name,value|
          message[name] && message[name].decoded == value
        end ||
        # If any of the following headers are present.
        [
          'X-Autogenerated',  # value is one of Forward, Group, Letter, Mirror, Redirect or Reply
          'X-AutoReply-From', # value is an email address
          'X-Autorespond',    # value is an email subject
          'X-Mail-Autoreply', # value is often "dtc-autoreply" but can be another tag
        ].any? do |name|
          message[name]
        end ||
        # If the Auto-Submitted header is present and is not equal to "no".
        (
          message['Auto-Submitted'] &&
          message['Auto-Submitted'].decoded != 'no'
        ) ||
        # If the message subject matches the autoresponse pattern.
        (
          MultiMail.autoresponse_pattern &&
          message.subject &&
          message.subject[MultiMail.autoresponse_pattern]
        )
      )
    end
  end
end

require 'multi_mail/service'
require 'multi_mail/receiver'
require 'multi_mail/message/base'
require 'multi_mail/receiver/base'
require 'multi_mail/sender/base'
