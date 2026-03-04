# frozen_string_literal: true

module CatcherPouch
  class Configuration
    # Lambda/proc that receives the controller instance and returns true if access is allowed.
    # Example: ->(controller) { controller.current_admin&.superadmin? }
    attr_accessor :authorization

    # Layout to use for the engine views. Set to a host app layout name (e.g., "backoffice")
    # or nil to use the engine's built-in standalone layout.
    attr_accessor :layout

    # Whether template editing (saving to disk) is enabled. Defaults to non-production.
    attr_accessor :editable

    # Hash of mailer_class => { action => proc_that_returns_mail_object }
    # Used to generate previews with real sample data.
    # Example:
    #   config.previews = {
    #     "UserMailer" => {
    #       "confirmation_code" => -> { UserMailer.confirmation_code(User.first || User.new(email: "test@example.com")) }
    #     }
    #   }
    attr_accessor :previews

    def initialize
      @authorization = ->(_controller) { true }
      @layout = nil
      @editable = !Rails.env.production?
      @previews = {}
    end
  end
end
