# frozen_string_literal: true

module CatcherPouch
  class ApplicationController < ::ApplicationController
    before_action :authorize_access!

    layout -> { CatcherPouch.config.layout || 'catcher_pouch/application' }

    # Ensure host app routes are available when using the host layout
    helper Rails.application.routes.url_helpers

    private

    def authorize_access!
      auth = CatcherPouch.config.authorization
      return if auth.nil?
      return if auth.call(self)

      render plain: 'Not authorized', status: :forbidden
    end
  end
end
