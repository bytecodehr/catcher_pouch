# frozen_string_literal: true

module CatcherPouch
  class ApplicationController < ::ApplicationController
    before_action :authorize_access!

    layout -> { CatcherPouch.config.layout || 'catcher_pouch/application' }

    # When using the host app's layout from an isolated engine, host route helpers
    # (e.g. backoffice_account_path) are not available in views. This helper module
    # delegates any unknown helper method to `main_app` (host routes) first, then
    # falls back to super. Engine route helpers (root_path, mailer_path, etc.) are
    # already included by Rails and take priority — method_missing only fires for
    # methods that don't exist yet.
    HOST_ROUTE_DELEGATOR = Module.new do
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

    helper HOST_ROUTE_DELEGATOR

    private

    def authorize_access!
      auth = CatcherPouch.config.authorization
      return if auth.nil?
      return if auth.call(self)

      render plain: 'Not authorized', status: :forbidden
    end
  end
end
