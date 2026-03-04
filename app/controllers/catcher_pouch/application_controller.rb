# frozen_string_literal: true

module CatcherPouch
  class ApplicationController < ::ApplicationController
    before_action :authorize_access!

    layout -> { CatcherPouch.config.layout || 'catcher_pouch/application' }

    # Delegate host app route helpers (e.g. backoffice_account_path) to main_app
    # so they work when rendering the host layout from an isolated engine
    def self.helpers_for_main_app
      Module.new do
        def method_missing(method, *args, **kwargs, &block)
          if main_app.respond_to?(method)
            main_app.send(method, *args, **kwargs, &block)
          else
            super
          end
        end

        def respond_to_missing?(method, include_private = false)
          main_app.respond_to?(method, include_private) || super
        end
      end
    end

    helper helpers_for_main_app

    private

    def authorize_access!
      auth = CatcherPouch.config.authorization
      return if auth.nil?
      return if auth.call(self)

      render plain: 'Not authorized', status: :forbidden
    end
  end
end
